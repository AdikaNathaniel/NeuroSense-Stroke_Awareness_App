import { IsEmail, IsNotEmpty, MinLength } from 'class-validator';

export class UpdatePasswordDto {
  @IsEmail()
  email: string;

  @IsNotEmpty()
  oldPassword: string;

  @IsNotEmpty()
  @MinLength(6)
  newPassword: string;
}
