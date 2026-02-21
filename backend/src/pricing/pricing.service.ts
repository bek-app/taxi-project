import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface PricingInput {
  distanceKm: number;
  durationMinutes: number;
  baseFare?: number;
  perKm?: number;
  perMinute?: number;
  surgeMultiplier?: number;
}

@Injectable()
export class PricingService {
  constructor(private readonly configService: ConfigService) {}

  getDefaultTariff(): { baseFare: number; perKm: number; perMinute: number; surgeMultiplier: number } {
    return {
      baseFare: this.getNumber('BASE_FARE', 500),
      perKm: this.getNumber('PER_KM', 120),
      perMinute: this.getNumber('PER_MINUTE', 25),
      surgeMultiplier: this.getNumber('SURGE_MULTIPLIER', 1),
    };
  }

  calculateFinalPrice(input: PricingInput): number {
    const defaults = this.getDefaultTariff();
    const baseFare = input.baseFare ?? defaults.baseFare;
    const perKm = input.perKm ?? defaults.perKm;
    const perMinute = input.perMinute ?? defaults.perMinute;
    const surgeMultiplier = input.surgeMultiplier ?? defaults.surgeMultiplier;

    const raw = (baseFare + input.distanceKm * perKm + input.durationMinutes * perMinute) * surgeMultiplier;
    return Number(raw.toFixed(2));
  }

  private getNumber(key: string, fallback: number): number {
    const raw = this.configService.get<string>(key);
    if (!raw) {
      return fallback;
    }

    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
}
