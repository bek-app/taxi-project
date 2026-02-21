import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DriversModule } from './drivers/drivers.module';
import { GeoModule } from './geo/geo.module';
import { HealthModule } from './health/health.module';
import { MatchmakingModule } from './matchmaking/matchmaking.module';
import { OrdersModule } from './orders/orders.module';
import { PricingModule } from './pricing/pricing.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: ['.env', '../.env'] }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres' as const,
        host: configService.get<string>('POSTGRES_HOST', 'localhost'),
        port: Number(configService.get<string>('POSTGRES_PORT', '5432')),
        database: configService.get<string>('POSTGRES_DB', 'taxi_mvp'),
        username: configService.get<string>('POSTGRES_USER', 'taxi_user'),
        password: configService.get<string>('POSTGRES_PASSWORD', 'taxi_password'),
        autoLoadEntities: true,
        synchronize: true,
      }),
    }),
    GeoModule,
    PricingModule,
    MatchmakingModule,
    OrdersModule,
    DriversModule,
    HealthModule,
  ],
})
export class AppModule {}
