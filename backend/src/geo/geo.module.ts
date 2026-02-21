import { Module } from '@nestjs/common';
import { RedisGeoService } from './redis-geo.service';

@Module({
  providers: [RedisGeoService],
  exports: [RedisGeoService],
})
export class GeoModule {}
