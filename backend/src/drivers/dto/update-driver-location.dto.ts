import { IsLatitude, IsLongitude } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateDriverLocationDto {
  @ApiProperty({ example: 43.238949 })
  @IsLatitude()
  latitude!: number;

  @ApiProperty({ example: 76.889709 })
  @IsLongitude()
  longitude!: number;
}
