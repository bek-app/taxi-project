import {
  ConflictException,
  ForbiddenException,
  Injectable,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { User } from './entities/user.entity';
import { AuthResponse } from './types/auth-response.type';
import { JwtPayload } from './types/jwt-payload.type';
import { UserRole } from './user-role.enum';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const normalizedEmail = dto.email.toLowerCase().trim();
    const existing = await this.userRepository.findOne({ where: { email: normalizedEmail } });

    if (existing) {
      throw new ConflictException('Email already exists');
    }

    if (dto.role === UserRole.ADMIN) {
      throw new ForbiddenException('Admin role cannot be registered publicly');
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

  async updateMe(
    userId: string,
    dto: UpdateMeDto,
  ): Promise<{ id: string; email: string; role: UserRole }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const nextEmailRaw = dto.email?.trim();
    if (nextEmailRaw && nextEmailRaw.length > 0) {
      const normalizedEmail = nextEmailRaw.toLowerCase();
      if (normalizedEmail !== user.email) {
        const existing = await this.userRepository.findOne({ where: { email: normalizedEmail } });
        if (existing && existing.id !== user.id) {
          throw new ConflictException('Email already exists');
        }
        user.email = normalizedEmail;
      }
    }

    const newPassword = dto.newPassword?.trim();
    if (newPassword && newPassword.length > 0) {
      const currentPassword = dto.currentPassword ?? '';
      if (!currentPassword) {
        throw new BadRequestException('Current password is required');
      }

      const isValidPassword = await bcrypt.compare(currentPassword, user.passwordHash);
      if (!isValidPassword) {
        throw new UnauthorizedException('Current password is incorrect');
      }

      user.passwordHash = await bcrypt.hash(newPassword, 10);
    }

    const saved = await this.userRepository.save(user);
    return {
      id: saved.id,
      email: saved.email,
      role: saved.role,
    };
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
