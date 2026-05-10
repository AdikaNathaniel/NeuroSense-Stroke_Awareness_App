import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { User, UserDocument } from './schemas/user.schema';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { EmailService } from '../email/email.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private jwtService: JwtService,
    private emailService: EmailService,
  ) {}

  // ── SIGNUP ──────────────────────────────────────────────────────────────────
  async signup(dto: CreateUserDto) {
    const existing = await this.userModel.findOne({ email: dto.email.toLowerCase() });
    if (existing) throw new BadRequestException('Email already registered');

    const hashed = await bcrypt.hash(dto.password, 12);
    const otp = this.generateOtp();
    const otpExpiryTime = new Date(Date.now() + 10 * 60 * 1000); // 10 min

    const user = await this.userModel.create({
      name: dto.name,
      email: dto.email.toLowerCase(),
      phone: dto.phone,
      password: hashed,
      otp,
      otpExpiryTime,
      isVerified: false,
    });

    await this.emailService.sendOtpEmail(user.email, user.name, otp);

    return { message: 'Registration successful. Check your email for the OTP.' };
  }

  // ── VERIFY OTP ───────────────────────────────────────────────────────────────
  async verifyEmail(otp: string, email: string) {
    const user = await this.userModel.findOne({ email: email.toLowerCase() });
    if (!user) throw new NotFoundException('User not found');
    if (user.isVerified) throw new BadRequestException('Account already verified');
    if (user.otp !== otp) throw new BadRequestException('Invalid OTP');
    if (new Date() > user.otpExpiryTime) throw new BadRequestException('OTP has expired. Request a new one.');

    user.isVerified = true;
    user.otp = undefined as any;
    user.otpExpiryTime = undefined as any;
    await user.save();

    return { message: 'Email verified successfully. You can now log in.' };
  }

  // ── RESEND OTP ───────────────────────────────────────────────────────────────
  async resendOtp(email: string) {
    const user = await this.userModel.findOne({ email: email.toLowerCase() });
    if (!user) throw new NotFoundException('User not found');
    if (user.isVerified) throw new BadRequestException('Account already verified');

    const otp = this.generateOtp();
    user.otp = otp;
    user.otpExpiryTime = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await this.emailService.sendOtpEmail(user.email, user.name, otp);
    return { message: 'OTP resent to your email.' };
  }

  // ── LOGIN ────────────────────────────────────────────────────────────────────
  async login(dto: LoginDto) {
    const user = await this.userModel.findOne({ email: dto.email.toLowerCase() });
    if (!user) throw new UnauthorizedException('Invalid email or password');
    if (!user.isActive) throw new UnauthorizedException('Account deactivated. Contact support.');
    if (!user.isVerified) throw new UnauthorizedException('Please verify your email before logging in.');

    // check account lock
    if (user.lockUntil && user.lockUntil > new Date()) {
      const remaining = Math.ceil((user.lockUntil.getTime() - Date.now()) / 60000);
      throw new UnauthorizedException(`Account locked. Try again in ${remaining} minute(s).`);
    }

    const passwordMatch = await bcrypt.compare(dto.password, user.password);
    if (!passwordMatch) {
      user.failedLoginAttempts += 1;
      if (user.failedLoginAttempts >= 3) {
        user.lockUntil = new Date(Date.now() + 15 * 60 * 1000); // lock 15 min
        user.failedLoginAttempts = 0;
      }
      await user.save();
      throw new UnauthorizedException('Invalid email or password');
    }

    // success — clear lock
    user.failedLoginAttempts = 0;
    user.lockUntil = undefined as any;
    await user.save();

    const token = this.jwtService.sign({ sub: user._id, email: user.email, name: user.name });
    return {
      message: 'Login successful',
      token,
      user: { id: user._id, name: user.name, email: user.email },
    };
  }

  // ── FORGOT PASSWORD ──────────────────────────────────────────────────────────
  async forgotPassword(email: string) {
    const user = await this.userModel.findOne({ email: email.toLowerCase() });
    if (!user) throw new NotFoundException('No account found with this email');

    const tempPassword = this.generateTempPassword();
    user.password = await bcrypt.hash(tempPassword, 12);
    user.failedLoginAttempts = 0;
    user.lockUntil = undefined as any;
    await user.save();

    await this.emailService.sendPasswordResetEmail(user.email, user.name, tempPassword);
    return { message: 'A temporary password has been sent to your email.' };
  }

  // ── UPDATE PASSWORD ──────────────────────────────────────────────────────────
  async updatePassword(dto: UpdatePasswordDto) {
    const user = await this.userModel.findOne({ email: dto.email.toLowerCase() });
    if (!user) throw new NotFoundException('User not found');

    const match = await bcrypt.compare(dto.oldPassword, user.password);
    if (!match) throw new BadRequestException('Old password is incorrect');

    user.password = await bcrypt.hash(dto.newPassword, 12);
    await user.save();
    return { message: 'Password updated successfully.' };
  }

  // ── PROFILE ──────────────────────────────────────────────────────────────────
  async getProfile(email: string) {
    const user = await this.userModel.findOne({ email: email.toLowerCase() }, '-password -otp -otpExpiryTime');
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────
  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private generateTempPassword(): string {
    const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefghjkmnpqrstwxyz23456789';
    return Array.from({ length: 10 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  }
}
