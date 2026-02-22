import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { AuthUser } from '../auth/types/auth-user.type';
import { UserRole } from '../auth/user-role.enum';
import { RedisGeoService } from '../geo/redis-geo.service';
import { MatchmakingService } from '../matchmaking/matchmaking.service';
import { PricingService } from '../pricing/pricing.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { Order } from './entities/order.entity';
import { OrderEventsGateway } from './order-events.gateway';
import { OrderStatus } from './order-status.enum';
import { isTransitionAllowed } from './order-transition.map';

@Injectable()
export class OrdersService {
  private static readonly BLOCKING_PASSENGER_STATUSES: OrderStatus[] = [
    OrderStatus.CREATED,
    OrderStatus.SEARCHING_DRIVER,
    OrderStatus.DRIVER_ASSIGNED,
    OrderStatus.DRIVER_ARRIVING,
    OrderStatus.IN_PROGRESS,
  ];
  private static readonly PICKUP_ARRIVAL_RADIUS_METERS = 120;

  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly pricingService: PricingService,
    private readonly matchmakingService: MatchmakingService,
    private readonly redisGeoService: RedisGeoService,
    private readonly orderEventsGateway: OrderEventsGateway,
  ) {}

  async listOrders(user: AuthUser): Promise<Order[]> {
    if (user.role === UserRole.ADMIN) {
      const orders = await this.orderRepository.find({ order: { createdAt: 'DESC' } });
      return this.attachDriverLocations(orders);
    }

    if (user.role === UserRole.CLIENT) {
      const orders = await this.orderRepository.find({
        where: { passengerId: user.userId },
        order: { createdAt: 'DESC' },
      });
      return this.attachDriverLocations(orders);
    }

    const orders = await this.orderRepository.find({
      where: { driverId: user.userId },
      order: { createdAt: 'DESC' },
    });
    return this.attachDriverLocations(orders);
  }

  async getOrderById(orderId: string, user?: AuthUser): Promise<Order> {
    const order = await this.orderRepository.findOne({ where: { id: orderId } });
    if (!order) {
      throw new NotFoundException(`Order not found: ${orderId}`);
    }

    if (user) {
      this.assertCanViewOrder(user, order);
    }

    return order;
  }

  async getOrderForResponse(orderId: string, user?: AuthUser): Promise<Order> {
    const order = await this.getOrderById(orderId, user);
    return this.attachDriverLocation(order);
  }

  async createOrder(dto: CreateOrderDto, _user?: AuthUser): Promise<Order> {
    await this.assertPassengerHasNoActiveOrder(dto.passengerId);

    const defaults = this.pricingService.getDefaultTariff();
    const baseFare = dto.baseFare ?? defaults.baseFare;
    const perKm = dto.perKm ?? defaults.perKm;
    const perMinute = dto.perMinute ?? defaults.perMinute;
    const surgeMultiplier = dto.surgeMultiplier ?? defaults.surgeMultiplier;

    const finalPrice = this.pricingService.calculateFinalPrice({
      distanceKm: dto.distanceKm,
      durationMinutes: dto.durationMinutes,
      baseFare,
      perKm,
      perMinute,
      surgeMultiplier,
    });

    const order = this.orderRepository.create({
      passengerId: dto.passengerId,
      driverId: null,
      canceledByRole: null,
      canceledByUserId: null,
      cityId: dto.cityId ?? null,
      pickupLatitude: dto.pickupLatitude,
      pickupLongitude: dto.pickupLongitude,
      dropoffLatitude: dto.dropoffLatitude,
      dropoffLongitude: dto.dropoffLongitude,
      distanceKm: dto.distanceKm,
      durationMinutes: Math.round(dto.durationMinutes),
      baseFare,
      perKm,
      perMinute,
      surgeMultiplier,
      finalPrice,
      status: OrderStatus.CREATED,
    });

    const saved = await this.orderRepository.save(order);
    this.orderEventsGateway.emitOrderUpdated(saved);
    return this.attachDriverLocation(saved);
  }

  async searchDriver(orderId: string, user: AuthUser): Promise<Order> {
    const order = await this.getOrderById(orderId);
    this.assertCanSearchDriver(user, order);

    if (order.status === OrderStatus.CREATED) {
      order.status = OrderStatus.SEARCHING_DRIVER;
      await this.orderRepository.save(order);
      this.orderEventsGateway.emitOrderUpdated(order);
    }

    if (order.status !== OrderStatus.SEARCHING_DRIVER) {
      throw new BadRequestException(`Order ${order.id} is not in SEARCHING_DRIVER state`);
    }

    const driverId = await this.matchmakingService.findDriverForOrder(order);
    if (!driverId) {
      return order;
    }

    order.driverId = driverId;
    order.status = OrderStatus.DRIVER_ASSIGNED;
    const saved = await this.orderRepository.save(order);
    await this.matchmakingService.setDriverBusy(driverId, true);
    this.orderEventsGateway.emitOrderUpdated(saved);
    return this.attachDriverLocation(saved);
  }

  async updateOrderStatus(
    orderId: string,
    dto: UpdateOrderStatusDto,
    user: AuthUser,
  ): Promise<Order> {
    const order = await this.getOrderById(orderId);
    const nextStatus = dto.status;
    this.assertCanUpdateStatus(user, order, nextStatus);

    if (!isTransitionAllowed(order.status, nextStatus)) {
      throw new BadRequestException(
        `Invalid status transition: ${order.status} -> ${nextStatus}`,
      );
    }

    if (nextStatus === OrderStatus.DRIVER_ASSIGNED && !order.driverId) {
      throw new BadRequestException('DRIVER_ASSIGNED state requires driverId');
    }

    if (nextStatus === OrderStatus.IN_PROGRESS) {
      await this.assertDriverReachedPickup(order);
    }

    if (nextStatus === OrderStatus.CANCELED) {
      order.canceledByRole = user.role;
      order.canceledByUserId = user.userId;
    } else if (order.status !== OrderStatus.CANCELED) {
      order.canceledByRole = null;
      order.canceledByUserId = null;
    }

    order.status = nextStatus;
    const saved = await this.orderRepository.save(order);

    if (saved.driverId && saved.status === OrderStatus.DRIVER_ARRIVING) {
      await this.matchmakingService.setDriverBusy(saved.driverId, true);
    }

    if (
      saved.driverId &&
      (saved.status === OrderStatus.CANCELED || saved.status === OrderStatus.COMPLETED)
    ) {
      await this.matchmakingService.releaseDriver(saved.driverId);
    }

    this.orderEventsGateway.emitOrderUpdated(saved);
    return this.attachDriverLocation(saved);
  }

  private assertCanViewOrder(user: AuthUser, order: Order): void {
    if (user.role === UserRole.ADMIN) {
      return;
    }

    if (user.role === UserRole.CLIENT && order.passengerId === user.userId) {
      return;
    }

    if (user.role === UserRole.DRIVER && order.driverId === user.userId) {
      return;
    }

    throw new ForbiddenException('You do not have access to this order');
  }

  private assertCanSearchDriver(user: AuthUser, order: Order): void {
    if (user.role === UserRole.ADMIN) {
      return;
    }

    if (user.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only client or admin can request matchmaking');
    }

    if (order.passengerId !== user.userId) {
      throw new ForbiddenException('You can search driver only for your own order');
    }
  }

  private assertCanUpdateStatus(
    user: AuthUser,
    order: Order,
    nextStatus: OrderStatus,
  ): void {
    if (user.role === UserRole.ADMIN) {
      return;
    }

    const driverOnlyStatuses = new Set<OrderStatus>([
      OrderStatus.DRIVER_ARRIVING,
      OrderStatus.IN_PROGRESS,
      OrderStatus.COMPLETED,
    ]);

    if (driverOnlyStatuses.has(nextStatus)) {
      if (user.role !== UserRole.DRIVER) {
        throw new ForbiddenException('Only driver can perform this status transition');
      }
      if (!order.driverId || order.driverId !== user.userId) {
        throw new ForbiddenException('Only assigned driver can update this order');
      }
      return;
    }

    if (nextStatus === OrderStatus.CANCELED) {
      const isPassenger = user.role === UserRole.CLIENT && order.passengerId === user.userId;
      const isAssignedDriver =
        user.role === UserRole.DRIVER &&
        order.driverId !== null &&
        order.driverId === user.userId;
      if (!isPassenger && !isAssignedDriver) {
        throw new ForbiddenException('Only passenger or assigned driver can cancel this order');
      }
      return;
    }

    if (nextStatus === OrderStatus.DRIVER_ASSIGNED) {
      throw new ForbiddenException('DRIVER_ASSIGNED is managed by matchmaking');
    }

    if (nextStatus === OrderStatus.SEARCHING_DRIVER) {
      throw new ForbiddenException('SEARCHING_DRIVER is managed by matchmaking');
    }
  }

  private async assertPassengerHasNoActiveOrder(passengerId: string): Promise<void> {
    const existing = await this.orderRepository.findOne({
      where: {
        passengerId,
        status: In(OrdersService.BLOCKING_PASSENGER_STATUSES),
      },
      order: { createdAt: 'DESC' },
    });

    if (!existing) {
      return;
    }

    throw new ConflictException(
      `Passenger already has active order: ${existing.id} (${existing.status})`,
    );
  }

  private async assertDriverReachedPickup(order: Order): Promise<void> {
    if (!order.driverId) {
      throw new BadRequestException('Cannot start ride without assigned driver');
    }

    const driverLocation = await this.redisGeoService.getDriverLocation(order.driverId);
    if (!driverLocation) {
      throw new BadRequestException('Driver location is unknown. Update location before starting ride');
    }

    const distanceMeters = this.distanceMeters(
      driverLocation.latitude,
      driverLocation.longitude,
      order.pickupLatitude,
      order.pickupLongitude,
    );

    if (distanceMeters > OrdersService.PICKUP_ARRIVAL_RADIUS_METERS) {
      throw new BadRequestException(
        `Driver is too far from pickup point (${Math.round(distanceMeters)}m > ${OrdersService.PICKUP_ARRIVAL_RADIUS_METERS}m)`,
      );
    }
  }

  private distanceMeters(
    latitude1: number,
    longitude1: number,
    latitude2: number,
    longitude2: number,
  ): number {
    const toRad = (value: number) => (value * Math.PI) / 180;
    const earthRadiusMeters = 6371000;
    const dLat = toRad(latitude2 - latitude1);
    const dLon = toRad(longitude2 - longitude1);
    const lat1Rad = toRad(latitude1);
    const lat2Rad = toRad(latitude2);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1Rad) * Math.cos(lat2Rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  private async attachDriverLocations(orders: Order[]): Promise<Order[]> {
    if (orders.length === 0) {
      return orders;
    }

    return Promise.all(orders.map((order) => this.attachDriverLocation(order)));
  }

  private async attachDriverLocation(order: Order): Promise<Order> {
    let driverLatitude: number | null = null;
    let driverLongitude: number | null = null;

    if (order.driverId) {
      const driverLocation = await this.redisGeoService.getDriverLocation(order.driverId);
      if (driverLocation) {
        driverLatitude = driverLocation.latitude;
        driverLongitude = driverLocation.longitude;
      }
    }

    return Object.assign(order, {
      driverLatitude,
      driverLongitude,
    });
  }
}
