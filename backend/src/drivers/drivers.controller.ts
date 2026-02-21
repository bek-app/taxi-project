import { Body, Controller, Param, Patch } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SetDriverAvailabilityDto } from './dto/set-driver-availability.dto';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { DriversService } from './drivers.service';

@ApiTags('Drivers')
@Controller('drivers')
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Patch(':driverId/location')
  async updateLocation(
    @Param('driverId') driverId: string,
    @Body() body: UpdateDriverLocationDto,
  ): Promise<{ ok: true; driverId: string }> {
    await this.driversService.updateLocation(driverId, body.latitude, body.longitude);
    return { ok: true, driverId };
  }

  @Patch(':driverId/availability')
  async setAvailability(
    @Param('driverId') driverId: string,
    @Body() body: SetDriverAvailabilityDto,
  ): Promise<{ ok: true; driverId: string; online: boolean }> {
    await this.driversService.setAvailability(driverId, body.online);
    return { ok: true, driverId, online: body.online };
  }
}
