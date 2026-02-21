import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'client@taxi.local' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: 'client123' })
  @IsString()
  @MinLength(6)
  password!: string;
}
