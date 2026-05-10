import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type UserDocument = User & Document;

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true })
  name: string;

  @Prop({ required: true, unique: true, lowercase: true })
  email: string;

  @Prop({ required: true })
  phone: string;

  @Prop({ required: true })
  password: string;

  @Prop({ default: false })
  isVerified: boolean;

  @Prop({ default: true })
  isActive: boolean;

  @Prop()
  otp: string;

  @Prop()
  otpExpiryTime: Date;

  @Prop({ default: 0 })
  failedLoginAttempts: number;

  @Prop()
  lockUntil: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);
