import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GeoModule } from '../geo/geo.module';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { PricingModule } from '../pricing/pricing.module';
import { Order } from './entities/order.entity';
import { OrderEventsGateway } from './order-events.gateway';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [TypeOrmModule.forFeature([Order]), MatchmakingModule, PricingModule, GeoModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrderEventsGateway],
  exports: [OrdersService],
})
export class OrdersModule {}
