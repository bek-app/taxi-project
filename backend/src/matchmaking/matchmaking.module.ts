import { Module } from '@nestjs/common';
import { GeoModule } from '../geo/geo.module';
import { MatchmakingService } from './matchmaking.service';

@Module({
  imports: [GeoModule],
  providers: [MatchmakingService],
  exports: [MatchmakingService],
})
export class MatchmakingModule {}
