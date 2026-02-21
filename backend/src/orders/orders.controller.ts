import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthUser } from '../auth/types/auth-user.type';
import { UserRole } from '../auth/user-role.enum';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { Order } from './entities/order.entity';
import { OrdersService } from './orders.service';

@ApiTags('Orders')
@ApiBearerAuth('jwt')
@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  listOrders(@Req() req: { user: AuthUser }): Promise<Order[]> {
    return this.ordersService.listOrders(req.user);
  }

  @Get(':orderId')
  getOrder(
    @Req() req: { user: AuthUser },
    @Param('orderId', new ParseUUIDPipe()) orderId: string,
  ): Promise<Order> {
    return this.ordersService.getOrderById(orderId, req.user);
  }

  @Post()
  createOrder(@Req() req: { user: AuthUser }, @Body() dto: CreateOrderDto): Promise<Order> {
    if (req.user.role === UserRole.DRIVER) {
      throw new ForbiddenException('Drivers cannot create orders');
    }
    if (req.user.role === UserRole.CLIENT && req.user.userId !== dto.passengerId) {
      throw new ForbiddenException('Client can create order only for own passengerId');
    }
    return this.ordersService.createOrder(dto, req.user);
  }

  @Post(':orderId/search-driver')
  searchDriver(
    @Req() req: { user: AuthUser },
    @Param('orderId', new ParseUUIDPipe()) orderId: string,
  ): Promise<Order> {
    return this.ordersService.searchDriver(orderId, req.user);
  }

  @Patch(':orderId/status')
  updateStatus(
    @Req() req: { user: AuthUser },
    @Param('orderId', new ParseUUIDPipe()) orderId: string,
    @Body() dto: UpdateOrderStatusDto,
  ): Promise<Order> {
    return this.ordersService.updateOrderStatus(orderId, dto, req.user);
  }
}
