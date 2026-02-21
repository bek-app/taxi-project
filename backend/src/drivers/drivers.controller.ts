import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AuthUser } from '../auth/types/auth-user.type';
import { UserRole } from '../auth/user-role.enum';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ListNearbyDriversDto } from './dto/list-nearby-drivers.dto';
import { SetDriverAvailabilityDto } from './dto/set-driver-availability.dto';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { DriversService } from './drivers.service';

@ApiTags('Drivers')
@ApiBearerAuth('jwt')
@UseGuards(JwtAuthGuard)
@Controller('drivers')
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Get('nearby')
  @ApiOkResponse({
    schema: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          driverId: { type: 'string', example: '9e9b8d6d-6fef-4f55-8b67-6e4f8e8df4f9' },
          latitude: { type: 'number', example: 43.24123 },
          longitude: { type: 'number', example: 76.90123 },
          distanceKm: { type: 'number', example: 1.235 },
        },
      },
    },
  })
  async listNearby(
    @Query() query: ListNearbyDriversDto,
  ): Promise<Array<{ driverId: string; latitude: number; longitude: number; distanceKm: number }>> {
    const radiusKm = query.radiusKm ?? 5;
    const limit = query.limit ?? 20;
    return this.driversService.listNearbyAvailableDrivers(
      query.latitude,
      query.longitude,
      radiusKm,
      limit,
    );
  }

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
