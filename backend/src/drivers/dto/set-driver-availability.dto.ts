import { IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SetDriverAvailabilityDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  online!: boolean;
}
