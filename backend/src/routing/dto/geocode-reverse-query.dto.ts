import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsLatitude, IsLongitude, IsOptional, IsString } from 'class-validator';

export class GeocodeReverseQueryDto {
  @ApiProperty({ example: 51.12824 })
  @IsLatitude()
  latitude!: number;

  @ApiProperty({ example: 71.43023 })
  @IsLongitude()
  longitude!: number;

  @ApiPropertyOptional({ example: 'kk,ru,en' })
  @IsOptional()
  @IsString()
  lang?: string;
}

