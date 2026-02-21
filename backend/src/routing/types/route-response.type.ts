import { RoutePoint } from './route-point.type';

export interface RouteResponse {
  distanceMeters: number;
  durationSeconds: number;
  distanceKm: number;
  durationMinutes: number;
  geometry: RoutePoint[];
  fromCache: boolean;
}
