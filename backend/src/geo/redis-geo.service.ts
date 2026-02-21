import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

export interface NearbyDriverLocation {
  driverId: string;
  latitude: number;
  longitude: number;
  distanceKm: number;
}

@Injectable()
export class RedisGeoService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisGeoService.name);
  private readonly redis: Redis;
  private readonly driversKey = 'drivers:geo';
  private readonly availabilityKey = 'drivers:availability';
  private readonly busyKey = 'drivers:busy';

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
    await this.redis.hdel(this.busyKey, driverId);
    await this.releaseDriverLock(driverId);
  }

  async setDriverBusy(driverId: string, busy: boolean): Promise<void> {
    if (busy) {
      await this.redis.hset(this.busyKey, driverId, '1');
      return;
    }
    await this.redis.hdel(this.busyKey, driverId);
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
    const busy = await this.redis.hmget(this.busyKey, ...driverIds);
    return driverIds.filter(
      (driverId, index) => availability[index] === '1' && busy[index] !== '1',
    );
  }

  async findNearbyAvailableDriverLocations(
    latitude: number,
    longitude: number,
    radiusKm: number,
    limit: number,
  ): Promise<NearbyDriverLocation[]> {
    const raw = (await this.redis.call(
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
      'WITHDIST',
      'WITHCOORD',
    )) as unknown;

    if (!Array.isArray(raw) || raw.length === 0) {
      return [];
    }

    const parsed: NearbyDriverLocation[] = [];
    for (const item of raw) {
      if (!Array.isArray(item) || item.length < 3) {
        continue;
      }

      const [driverIdRaw, distanceRaw, coordRaw] = item as unknown[];
      const driverId = String(driverIdRaw ?? '').trim();
      if (!driverId) {
        continue;
      }

      const distanceKm = Number(distanceRaw);
      if (!Number.isFinite(distanceKm)) {
        continue;
      }

      if (!Array.isArray(coordRaw) || coordRaw.length < 2) {
        continue;
      }

      const lon = Number(coordRaw[0]);
      const lat = Number(coordRaw[1]);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
        continue;
      }

      parsed.push({
        driverId,
        latitude: Number(lat.toFixed(6)),
        longitude: Number(lon.toFixed(6)),
        distanceKm: Number(distanceKm.toFixed(3)),
      });
    }

    if (parsed.length === 0) {
      return [];
    }

    const availability = await this.redis.hmget(
      this.availabilityKey,
      ...parsed.map((item) => item.driverId),
    );
    const busy = await this.redis.hmget(
      this.busyKey,
      ...parsed.map((item) => item.driverId),
    );
    return parsed.filter((item, index) => availability[index] === '1' && busy[index] !== '1');
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
