import {
  BadRequestException,
  GatewayTimeoutException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RoutePoint } from './types/route-point.type';
import { RouteResponse } from './types/route-response.type';

interface CacheEntry {
  expiresAt: number;
  value: Omit<RouteResponse, 'fromCache'>;
}

@Injectable()
export class RoutingService {
  private readonly cache = new Map<string, CacheEntry>();
  private readonly inflight = new Map<string, Promise<RouteResponse>>();

  constructor(private readonly configService: ConfigService) {}

  async getRoute(coordinatesParam: string): Promise<RouteResponse> {
    const waypoints = this.parseCoordinates(coordinatesParam);
    const cacheKey = this.toCacheKey(waypoints);
    const now = Date.now();

    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > now) {
      return {
        ...cached.value,
        fromCache: true,
      };
    }

    const existingPromise = this.inflight.get(cacheKey);
    if (existingPromise) {
      return existingPromise;
    }

    const promise = this.fetchAndCacheRoute(cacheKey, waypoints);
    this.inflight.set(cacheKey, promise);

    try {
      return await promise;
    } finally {
      this.inflight.delete(cacheKey);
    }
  }

  private async fetchAndCacheRoute(
    cacheKey: string,
    waypoints: RoutePoint[],
  ): Promise<RouteResponse> {
    const value = await this.fetchFromProvider(waypoints);
    this.cache.set(cacheKey, {
      value,
      expiresAt: Date.now() + this.cacheTtlMs,
    });
    return {
      ...value,
      fromCache: false,
    };
  }

  private async fetchFromProvider(
    waypoints: RoutePoint[],
  ): Promise<Omit<RouteResponse, 'fromCache'>> {
    const coordinates = waypoints
      .map((point) => `${point.lng.toFixed(6)},${point.lat.toFixed(6)}`)
      .join(';');

    const baseUrl = this.configService.get<string>(
      'ROUTING_PROVIDER_URL',
      'https://router.project-osrm.org',
    );

    const url = new URL(`/route/v1/driving/${coordinates}`, baseUrl);
    url.searchParams.set('alternatives', 'false');
    url.searchParams.set('overview', 'full');
    url.searchParams.set('geometries', 'geojson');
    url.searchParams.set('steps', 'false');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.requestTimeoutMs);

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
      });
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        throw new GatewayTimeoutException('Routing provider timeout');
      }
      throw new ServiceUnavailableException('Routing provider unavailable');
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new ServiceUnavailableException(
        `Routing provider error: ${response.status}`,
      );
    }

    const json = (await response.json()) as Record<string, unknown>;
    const routes = json['routes'];
    if (!Array.isArray(routes) || routes.length === 0) {
      throw new ServiceUnavailableException('Routing provider returned no routes');
    }

    const route = routes[0] as Record<string, unknown>;
    const distanceMeters = this.toNumber(route['distance']);
    const durationSeconds = this.toNumber(route['duration']);

    const geometryContainer = route['geometry'] as Record<string, unknown> | undefined;
    const geometryCoordinates = geometryContainer?.['coordinates'];
    if (!Array.isArray(geometryCoordinates) || geometryCoordinates.length < 2) {
      throw new ServiceUnavailableException('Routing provider geometry is invalid');
    }

    const geometry: RoutePoint[] = [];
    for (const item of geometryCoordinates) {
      if (!Array.isArray(item) || item.length < 2) {
        continue;
      }
      const lng = this.toNumber(item[0]);
      const lat = this.toNumber(item[1]);
      geometry.push({ lat, lng });
    }

    if (geometry.length < 2) {
      throw new ServiceUnavailableException('Routing provider geometry is too short');
    }

    return {
      distanceMeters: Number(distanceMeters.toFixed(1)),
      durationSeconds: Number(durationSeconds.toFixed(1)),
      distanceKm: Number((distanceMeters / 1000).toFixed(2)),
      durationMinutes: Number((durationSeconds / 60).toFixed(1)),
      geometry,
    };
  }

  private parseCoordinates(input: string): RoutePoint[] {
    const parts = input
      .split(';')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    if (parts.length < 2 || parts.length > 5) {
      throw new BadRequestException('coordinates must contain between 2 and 5 points');
    }

    const points: RoutePoint[] = [];
    for (const part of parts) {
      const [lngRaw, latRaw, ...rest] = part.split(',').map((item) => item.trim());
      if (!lngRaw || !latRaw || rest.length > 0) {
        throw new BadRequestException('coordinates format must be "lng,lat;lng,lat"');
      }

      const lng = Number(lngRaw);
      const lat = Number(latRaw);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        throw new BadRequestException('coordinates contain invalid numbers');
      }

      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        throw new BadRequestException('coordinates are out of range');
      }

      points.push({ lat, lng });
    }

    return points;
  }

  private toCacheKey(points: RoutePoint[]): string {
    return points
      .map((point) => `${point.lat.toFixed(5)},${point.lng.toFixed(5)}`)
      .join('|');
  }

  private toNumber(value: unknown): number {
    const number = Number(value);
    if (!Number.isFinite(number)) {
      throw new ServiceUnavailableException('Routing provider returned invalid number');
    }
    return number;
  }

  private get requestTimeoutMs(): number {
    return Number(this.configService.get<string>('ROUTING_TIMEOUT_MS', '8000'));
  }

  private get cacheTtlMs(): number {
    const ttlSec = Number(this.configService.get<string>('ROUTING_CACHE_TTL_SEC', '120'));
    return ttlSec * 1000;
  }
}
