import { Injectable } from '@nestjs/common';
import { NearbyDriverLocation, RedisGeoService } from '../geo/redis-geo.service';

@Injectable()
export class DriversService {
  constructor(private readonly redisGeoService: RedisGeoService) {}

  async updateLocation(driverId: string, latitude: number, longitude: number): Promise<void> {
    await this.redisGeoService.updateDriverLocation(driverId, latitude, longitude);
  }

  async setAvailability(driverId: string, online: boolean): Promise<void> {
    await this.redisGeoService.setDriverAvailability(driverId, online);
  }

  async listNearbyAvailableDrivers(
    latitude: number,
    longitude: number,
    radiusKm: number,
    limit: number,
  ): Promise<NearbyDriverLocation[]> {
    return this.redisGeoService.findNearbyAvailableDriverLocations(
      latitude,
      longitude,
      radiusKm,
      limit,
    );
  }
}
