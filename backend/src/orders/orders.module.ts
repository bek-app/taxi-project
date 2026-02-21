import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { PricingModule } from '../pricing/pricing.module';
import { Order } from './entities/order.entity';
import { OrderEventsGateway } from './order-events.gateway';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [TypeOrmModule.forFeature([Order]), MatchmakingModule, PricingModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrderEventsGateway],
  exports: [OrdersService],
})
export class OrdersModule {}
