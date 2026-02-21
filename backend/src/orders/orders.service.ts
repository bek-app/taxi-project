import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
  constructor(
    @InjectRepository(Order)
    private readonly orderRepository: Repository<Order>,
    private readonly pricingService: PricingService,
    private readonly matchmakingService: MatchmakingService,
    private readonly orderEventsGateway: OrderEventsGateway,
  ) {}

  async listOrders(): Promise<Order[]> {
    return this.orderRepository.find({ order: { createdAt: 'DESC' } });
  }

  async getOrderById(orderId: string): Promise<Order> {
    const order = await this.orderRepository.findOne({ where: { id: orderId } });
    if (!order) {
      throw new NotFoundException(`Order not found: ${orderId}`);
    }

    return order;
  }

  async createOrder(dto: CreateOrderDto): Promise<Order> {
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
    return saved;
  }

  async searchDriver(orderId: string): Promise<Order> {
    const order = await this.getOrderById(orderId);

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
    this.orderEventsGateway.emitOrderUpdated(saved);
    return saved;
  }

  async updateOrderStatus(orderId: string, dto: UpdateOrderStatusDto): Promise<Order> {
    const order = await this.getOrderById(orderId);
    const nextStatus = dto.status;

    if (!isTransitionAllowed(order.status, nextStatus)) {
      throw new BadRequestException(
        `Invalid status transition: ${order.status} -> ${nextStatus}`,
      );
    }

    if (nextStatus === OrderStatus.DRIVER_ASSIGNED && !order.driverId) {
      throw new BadRequestException('DRIVER_ASSIGNED state requires driverId');
    }

    order.status = nextStatus;
    const saved = await this.orderRepository.save(order);

    if (
      saved.driverId &&
      (saved.status === OrderStatus.CANCELED || saved.status === OrderStatus.COMPLETED)
    ) {
      await this.matchmakingService.releaseDriver(saved.driverId);
    }

    this.orderEventsGateway.emitOrderUpdated(saved);
    return saved;
  }
}
