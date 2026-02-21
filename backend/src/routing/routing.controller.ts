import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { GeocodeReverseQueryDto } from './dto/geocode-reverse-query.dto';
import { GeocodeSearchQueryDto } from './dto/geocode-search-query.dto';
import { RouteQueryDto } from './dto/route-query.dto';
import { RoutingService } from './routing.service';
import { RouteResponse } from './types/route-response.type';

@ApiTags('Routing')
@Controller('routing')
export class RoutingController {
  constructor(private readonly routingService: RoutingService) {}

  @Get('geocode/search')
  @ApiOperation({
    summary: 'Search places by free text query',
  })
  @ApiOkResponse({
    description: 'Place suggestions',
    schema: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          displayName: { type: 'string', example: 'Бәйтерек, Астана, Казахстан' },
          latitude: { type: 'number', example: 51.12824 },
          longitude: { type: 'number', example: 71.43023 },
        },
      },
    },
  })
  async searchGeocode(
    @Query() query: GeocodeSearchQueryDto,
  ): Promise<Array<{ displayName: string; latitude: number; longitude: number }>> {
    return this.routingService.searchGeocode(query.q, {
      limit: query.limit,
      lang: query.lang,
      countryCode: query.countryCode,
      viewBox: query.viewBox,
    });
  }

  @Get('geocode/reverse')
  @ApiOperation({
    summary: 'Reverse geocode coordinates',
  })
  @ApiOkResponse({
    description: 'Reverse geocoding details',
    schema: {
      oneOf: [
        {
          type: 'null',
        },
        {
          type: 'object',
          properties: {
            displayName: { type: 'string', example: 'Astana, Kazakhstan' },
            shortAddress: { type: 'string', example: 'Astana, Kazakhstan' },
            cityName: { type: 'string', nullable: true, example: 'Astana' },
            cityId: { type: 'string', nullable: true, example: 'astana' },
            cityViewBox: { type: 'string', nullable: true, example: '71.3,51.2,71.5,51.0' },
            countryCode: { type: 'string', nullable: true, example: 'kz' },
          },
        },
      ],
    },
  })
  reverseGeocode(@Query() query: GeocodeReverseQueryDto) {
    return this.routingService.reverseGeocode(
      query.latitude,
      query.longitude,
      query.lang,
    );
  }

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
