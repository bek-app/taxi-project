import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator';

export class GeocodeSearchQueryDto {
  @ApiProperty({ example: 'Байтерек' })
  @IsString()
  q!: string;

  @ApiPropertyOptional({ example: 5, default: 5, minimum: 1, maximum: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  limit?: number;

  @ApiPropertyOptional({ example: 'kk,ru,en' })
  @IsOptional()
  @IsString()
  lang?: string;

  @ApiPropertyOptional({ example: 'kz' })
  @IsOptional()
  @Matches(/^[a-zA-Z]{2}$/)
  countryCode?: string;

  @ApiPropertyOptional({
    example: '71.30,51.25,71.55,51.05',
    description: 'west,north,east,south',
  })
  @IsOptional()
  @IsString()
  viewBox?: string;
}

