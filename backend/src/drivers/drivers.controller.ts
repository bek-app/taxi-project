import {
  Body,
  Controller,
  ForbiddenException,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser } from '../auth/types/auth-user.type';
import { UserRole } from '../auth/user-role.enum';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SetDriverAvailabilityDto } from './dto/set-driver-availability.dto';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { DriversService } from './drivers.service';

@ApiTags('Drivers')
@ApiBearerAuth('jwt')
@UseGuards(JwtAuthGuard)
@Controller('drivers')
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Patch('me/location')
  async updateMyLocation(
    @Req() req: { user: AuthUser },
    @Body() body: UpdateDriverLocationDto,
  ): Promise<{ ok: true; driverId: string }> {
    const driverId = this.resolveDriverId(req.user);
    await this.driversService.updateLocation(driverId, body.latitude, body.longitude);
    return { ok: true, driverId };
  }

  @Patch(':driverId/location')
  async updateLocation(
    @Req() req: { user: AuthUser },
    @Param('driverId') driverId: string,
    @Body() body: UpdateDriverLocationDto,
  ): Promise<{ ok: true; driverId: string }> {
    const resolvedDriverId = this.resolveDriverId(req.user, driverId);
    await this.driversService.updateLocation(
      resolvedDriverId,
      body.latitude,
      body.longitude,
    );
    return { ok: true, driverId: resolvedDriverId };
  }

  @Patch('me/availability')
  async setMyAvailability(
    @Req() req: { user: AuthUser },
    @Body() body: SetDriverAvailabilityDto,
  ): Promise<{ ok: true; driverId: string; online: boolean }> {
    const driverId = this.resolveDriverId(req.user);
    await this.driversService.setAvailability(driverId, body.online);
    return { ok: true, driverId, online: body.online };
  }

  @Patch(':driverId/availability')
  async setAvailability(
    @Req() req: { user: AuthUser },
    @Param('driverId') driverId: string,
    @Body() body: SetDriverAvailabilityDto,
  ): Promise<{ ok: true; driverId: string; online: boolean }> {
    const resolvedDriverId = this.resolveDriverId(req.user, driverId);
    await this.driversService.setAvailability(resolvedDriverId, body.online);
    return { ok: true, driverId: resolvedDriverId, online: body.online };
  }

  private resolveDriverId(user: AuthUser, requestedDriverId?: string): string {
    if (user.role === UserRole.ADMIN) {
      return requestedDriverId ?? user.userId;
    }

    if (user.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can update availability and location');
    }

    if (requestedDriverId && requestedDriverId !== user.userId) {
      throw new ForbiddenException('You can update only your own driver profile');
    }

    return user.userId;
  }
}
