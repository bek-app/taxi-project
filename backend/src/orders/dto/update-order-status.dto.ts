import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { OrderStatus } from '../order-status.enum';

export class UpdateOrderStatusDto {
  @ApiProperty({ enum: OrderStatus, example: OrderStatus.DRIVER_ARRIVING })
  @IsEnum(OrderStatus)
  status!: OrderStatus;
}
