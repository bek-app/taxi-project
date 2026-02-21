import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RedisGeoService } from '../geo/redis-geo.service';
import { Order } from '../orders/entities/order.entity';

@Injectable()
export class MatchmakingService {
  constructor(
    private readonly configService: ConfigService,
    private readonly redisGeoService: RedisGeoService,
  ) {}

  async findDriverForOrder(order: Order): Promise<string | null> {
    const baseRadius = Number(this.configService.get<string>('MATCH_RADIUS_KM', '5'));
    const limit = Number(this.configService.get<string>('MATCH_LIMIT', '10'));
    const offerTtl = Number(this.configService.get<string>('MATCH_OFFER_TTL_SEC', '30'));

    const radiuses = [baseRadius, baseRadius * 2, baseRadius * 3];

    for (const radius of radiuses) {
      const candidates = await this.redisGeoService.findNearbyAvailableDrivers(
        order.pickupLatitude,
        order.pickupLongitude,
        radius,
        limit,
      );

      for (const driverId of candidates) {
        const claimed = await this.redisGeoService.claimDriverForOrder(driverId, order.id, offerTtl);
        if (claimed) {
          return driverId;
        }
      }
    }

    return null;
  }

  async releaseDriver(driverId: string): Promise<void> {
    await this.redisGeoService.setDriverBusy(driverId, false);
    await this.redisGeoService.releaseDriverLock(driverId);
  }

  async setDriverBusy(driverId: string, busy: boolean): Promise<void> {
    await this.redisGeoService.setDriverBusy(driverId, busy);
  }
}
