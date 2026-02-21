import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { RouteQueryDto } from './dto/route-query.dto';
import { RoutingService } from './routing.service';
import { RouteResponse } from './types/route-response.type';

@ApiTags('Routing')
@Controller('routing')
export class RoutingController {
  constructor(private readonly routingService: RoutingService) {}

  @Get('route')
  @ApiOperation({
    summary: 'Calculate driving route for 2 to 5 waypoints',
  })
  @ApiQuery({
    name: 'coordinates',
    required: true,
    description: 'Semicolon-separated "lng,lat" points (example: lng,lat;lng,lat)',
    example: '76.889709,43.238949;76.924758,43.240978',
  })
  @ApiOkResponse({
    description: 'Route summary and geometry',
    schema: {
      type: 'object',
      properties: {
        distanceMeters: { type: 'number', example: 8732.4 },
        durationSeconds: { type: 'number', example: 1224.2 },
        distanceKm: { type: 'number', example: 8.73 },
        durationMinutes: { type: 'number', example: 20.4 },
        fromCache: { type: 'boolean', example: false },
        geometry: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              lat: { type: 'number', example: 43.238949 },
              lng: { type: 'number', example: 76.889709 },
            },
          },
        },
      },
    },
  })
  getRoute(@Query() query: RouteQueryDto): Promise<RouteResponse> {
    return this.routingService.getRoute(query.coordinates);
  }
}
