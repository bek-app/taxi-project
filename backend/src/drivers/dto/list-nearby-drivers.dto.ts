import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class ListNearbyDriversDto {
  @ApiProperty({ example: 43.238949 })
  @IsLatitude()
  latitude!: number;

  @ApiProperty({ example: 76.889709 })
  @IsLongitude()
  longitude!: number;

  @ApiPropertyOptional({ example: 5, default: 5, minimum: 0.5, maximum: 20 })
  @IsOptional()
  @IsNumber()
  @Min(0.5)
  @Max(20)
  radiusKm?: number;

  @ApiPropertyOptional({ example: 20, default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number;
}
