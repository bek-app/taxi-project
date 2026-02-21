import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
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
  listOrders(): Promise<Order[]> {
    return this.ordersService.listOrders();
  }

  @Get(':orderId')
  getOrder(@Param('orderId', new ParseUUIDPipe()) orderId: string): Promise<Order> {
    return this.ordersService.getOrderById(orderId);
  }

  @Post()
  createOrder(@Body() dto: CreateOrderDto): Promise<Order> {
    return this.ordersService.createOrder(dto);
  }

  @Post(':orderId/search-driver')
  searchDriver(@Param('orderId', new ParseUUIDPipe()) orderId: string): Promise<Order> {
    return this.ordersService.searchDriver(orderId);
  }

  @Patch(':orderId/status')
  updateStatus(
    @Param('orderId', new ParseUUIDPipe()) orderId: string,
    @Body() dto: UpdateOrderStatusDto,
  ): Promise<Order> {
    return this.ordersService.updateOrderStatus(orderId, dto);
  }
}
