import { ConflictException, Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { User } from './entities/user.entity';
import { AuthResponse } from './types/auth-response.type';
import { JwtPayload } from './types/jwt-payload.type';
import { UserRole } from './user-role.enum';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.seedDemoUsers();
  }

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const normalizedEmail = dto.email.toLowerCase().trim();
    const existing = await this.userRepository.findOne({ where: { email: normalizedEmail } });

    if (existing) {
      throw new ConflictException('Email already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = this.userRepository.create({
      email: normalizedEmail,
      passwordHash,
      role: dto.role ?? UserRole.CLIENT,
    });

    const saved = await this.userRepository.save(user);
    return this.toAuthResponse(saved);
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const normalizedEmail = dto.email.toLowerCase().trim();
    const user = await this.userRepository.findOne({ where: { email: normalizedEmail } });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isValidPassword = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isValidPassword) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.toAuthResponse(user);
  }

  async me(userId: string): Promise<{ id: string; email: string; role: UserRole }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
    };
  }

  private async seedDemoUsers(): Promise<void> {
    const demos: Array<{ email: string; password: string; role: UserRole }> = [
      {
        email: this.configService.get<string>('DEMO_CLIENT_EMAIL', 'client@taxi.local'),
        password: this.configService.get<string>('DEMO_CLIENT_PASSWORD', 'client123'),
        role: UserRole.CLIENT,
      },
      {
        email: this.configService.get<string>('DEMO_DRIVER_EMAIL', 'driver@taxi.local'),
        password: this.configService.get<string>('DEMO_DRIVER_PASSWORD', 'driver123'),
        role: UserRole.DRIVER,
      },
      {
        email: this.configService.get<string>('DEMO_ADMIN_EMAIL', 'admin@taxi.local'),
        password: this.configService.get<string>('DEMO_ADMIN_PASSWORD', 'admin123'),
        role: UserRole.ADMIN,
      },
    ];

    for (const demo of demos) {
      const email = demo.email.toLowerCase().trim();
      const existing = await this.userRepository.findOne({ where: { email } });
      if (existing) {
        continue;
      }

      const passwordHash = await bcrypt.hash(demo.password, 10);
      const user = this.userRepository.create({
        email,
        passwordHash,
        role: demo.role,
      });
      await this.userRepository.save(user);
    }
  }

  private toAuthResponse(user: User): AuthResponse {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
      },
    };
  }
}
