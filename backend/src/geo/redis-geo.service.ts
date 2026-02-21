import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisGeoService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisGeoService.name);
  private readonly redis: Redis;
  private readonly driversKey = 'drivers:geo';
  private readonly availabilityKey = 'drivers:availability';

  constructor(private readonly configService: ConfigService) {
    const host = this.configService.get<string>('REDIS_HOST', 'localhost');
    const port = Number(this.configService.get<string>('REDIS_PORT', '6379'));
    const password = this.configService.get<string>('REDIS_PASSWORD') || undefined;

    this.redis = new Redis({ host, port, password, lazyConnect: false });
    this.redis.on('error', (error) => {
      this.logger.error(`Redis error: ${error.message}`);
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.redis.quit();
  }

  async setDriverAvailability(driverId: string, online: boolean): Promise<void> {
    if (online) {
      await this.redis.hset(this.availabilityKey, driverId, '1');
      return;
    }

    await this.redis.hdel(this.availabilityKey, driverId);
    await this.releaseDriverLock(driverId);
  }

  async updateDriverLocation(driverId: string, latitude: number, longitude: number): Promise<void> {
    await this.redis.geoadd(this.driversKey, longitude, latitude, driverId);
  }

  async findNearbyAvailableDrivers(
    latitude: number,
    longitude: number,
    radiusKm: number,
    limit: number,
  ): Promise<string[]> {
    const result = (await this.redis.call(
      'GEOSEARCH',
      this.driversKey,
      'FROMLONLAT',
      String(longitude),
      String(latitude),
      'BYRADIUS',
      String(radiusKm),
      'km',
      'ASC',
      'COUNT',
      String(limit),
    )) as string[];

    const driverIds = Array.isArray(result) ? result : [];
    if (driverIds.length === 0) {
      return [];
    }

    const availability = await this.redis.hmget(this.availabilityKey, ...driverIds);
    return driverIds.filter((driverId, index) => availability[index] === '1');
  }

  async claimDriverForOrder(driverId: string, orderId: string, ttlSeconds: number): Promise<boolean> {
    const lockKey = this.driverLockKey(driverId);
    const lockResult = await this.redis.set(lockKey, orderId, 'EX', ttlSeconds, 'NX');
    return lockResult === 'OK';
  }

  async releaseDriverLock(driverId: string): Promise<void> {
    await this.redis.del(this.driverLockKey(driverId));
  }

  private driverLockKey(driverId: string): string {
    return `drivers:lock:${driverId}`;
  }
}
