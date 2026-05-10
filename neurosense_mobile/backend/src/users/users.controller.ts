import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { JwtAuthGuard } from '../shared/guards/jwt-auth.guard';

@Controller('api/v1/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  signup(@Body() dto: CreateUserDto) {
    return this.usersService.signup(dto);
  }

  @Get('verify-email/:otp/:email')
  verifyEmail(@Param('otp') otp: string, @Param('email') email: string) {
    return this.usersService.verifyEmail(otp, email);
  }

  @Get('send-otp/:email')
  resendOtp(@Param('email') email: string) {
    return this.usersService.resendOtp(email);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.usersService.login(dto);
  }

  @Get('forgot-password/:email')
  forgotPassword(@Param('email') email: string) {
    return this.usersService.forgotPassword(email);
  }

  @Patch('update-password')
  @UseGuards(JwtAuthGuard)
  updatePassword(@Body() dto: UpdatePasswordDto) {
    return this.usersService.updatePassword(dto);
  }

  @Get('profile/:email')
  @UseGuards(JwtAuthGuard)
  getProfile(@Param('email') email: string) {
    return this.usersService.getProfile(email);
  }
}
