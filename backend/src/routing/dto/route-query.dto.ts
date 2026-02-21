import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class RouteQueryDto {
  @ApiProperty({
    example: '76.889709,43.238949;76.924758,43.240978',
    description: 'Semicolon-separated "lng,lat" points (2 to 5 points)',
  })
  @IsString()
  @Matches(/^[-0-9.,;\s]+$/)
  coordinates!: string;
}
