import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateOrderDto {
  @ApiProperty({ example: 'f3a51fc6-fd09-4c32-8c6f-46fd019e3472' })
  @IsUUID()
  passengerId!: string;

  @ApiPropertyOptional({ example: 'almaty' })
  @IsOptional()
  @IsString()
  cityId?: string;

  @ApiProperty({ example: 43.238949 })
  @IsLatitude()
  pickupLatitude!: number;

  @ApiProperty({ example: 76.889709 })
  @IsLongitude()
  pickupLongitude!: number;

  @ApiProperty({ example: 43.240978 })
  @IsLatitude()
  dropoffLatitude!: number;

  @ApiProperty({ example: 76.924758 })
  @IsLongitude()
  dropoffLongitude!: number;

  @ApiProperty({ example: 8.5 })
  @IsNumber()
  @IsPositive()
  distanceKm!: number;

  @ApiProperty({ example: 18 })
  @IsNumber()
  @IsPositive()
  durationMinutes!: number;

  @ApiPropertyOptional({ example: 500 })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  baseFare?: number;

  @ApiPropertyOptional({ example: 120 })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  perKm?: number;

  @ApiPropertyOptional({ example: 25 })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  perMinute?: number;

  @ApiPropertyOptional({ example: 1.25, minimum: 1, maximum: 3 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(3)
  surgeMultiplier?: number;
}
