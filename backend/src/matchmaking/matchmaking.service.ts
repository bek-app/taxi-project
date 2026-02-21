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
    const configuredMaxRadius = Number(this.configService.get<string>('MATCH_MAX_RADIUS_KM', '60'));
    const limit = Number(this.configService.get<string>('MATCH_LIMIT', '10'));
    const offerTtl = Number(this.configService.get<string>('MATCH_OFFER_TTL_SEC', '30'));

    const normalizedBaseRadius = Number.isFinite(baseRadius) && baseRadius > 0 ? baseRadius : 5;
    const normalizedMaxRadius =
      Number.isFinite(configuredMaxRadius) && configuredMaxRadius > 0
        ? Math.max(configuredMaxRadius, normalizedBaseRadius)
        : Math.max(normalizedBaseRadius, 60);

    const radiuses = Array.from(
      new Set([
        normalizedBaseRadius,
        normalizedBaseRadius * 2,
        normalizedBaseRadius * 4,
        normalizedMaxRadius,
      ]),
    )
      .filter((radius) => radius > 0)
      .sort((a, b) => a - b);

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
