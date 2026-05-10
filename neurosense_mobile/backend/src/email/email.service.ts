import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import * as path from 'path';

@Injectable()
export class EmailService {
  private transporter: nodemailer.Transporter;

  constructor(private config: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: config.get('SMTP_HOST'),
      port: Number(config.get('SMTP_PORT')),
      secure: config.get('SMTP_SECURE') === 'true',
      auth: {
        user: config.get('SMTP_USER'),
        pass: config.get('SMTP_PASS'),
      },
    });
  }

  private get logoPath(): string {
    return path.join(process.cwd(), 'assets', 'logo.png');
  }

  private get logoAttachment() {
    return {
      filename: 'logo.png',
      path: this.logoPath,
      cid: 'neurosense-logo',
    };
  }

  async sendOtpEmail(email: string, name: string, otp: string) {
    await this.transporter.sendMail({
      from: `"NeuroSense" <${this.config.get('SMTP_USER')}>`,
      to: email,
      subject: 'Verify your NeuroSense account',
      html: this.otpTemplate(name, otp),
      attachments: [this.logoAttachment],
    });
  }

  async sendPasswordResetEmail(email: string, name: string, tempPassword: string) {
    await this.transporter.sendMail({
      from: `"NeuroSense" <${this.config.get('SMTP_USER')}>`,
      to: email,
      subject: 'NeuroSense — Password Reset',
      html: this.resetTemplate(name, tempPassword),
      attachments: [this.logoAttachment],
    });
  }

  private otpTemplate(name: string, otp: string): string {
    return `
    <div style="font-family:Inter,sans-serif;max-width:520px;margin:auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(21,101,192,0.10);">
      <div style="background:linear-gradient(135deg,#1565C0,#1E88E5);padding:32px 24px;text-align:center;">
        <img src="cid:neurosense-logo" alt="NeuroSense" style="width:80px;height:80px;object-fit:contain;border-radius:16px;margin-bottom:16px;display:block;margin-left:auto;margin-right:auto;" />
        <h1 style="color:#fff;margin:0;font-size:24px;font-weight:700;">NeuroSense</h1>
        <p style="color:#E3F2FD;margin:4px 0 0;font-size:13px;">Stroke Awareness & Prediction</p>
      </div>
      <div style="padding:32px 24px;">
        <h2 style="color:#0D1B2A;margin:0 0 8px;">Hi ${name} 👋</h2>
        <p style="color:#546E7A;margin:0 0 24px;">Use the code below to verify your email address. This code expires in <strong>10 minutes</strong>.</p>
        <div style="background:#F5F9FF;border:2px dashed #1E88E5;border-radius:12px;padding:24px;text-align:center;margin-bottom:24px;">
          <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#1565C0;">${otp}</span>
        </div>
        <p style="color:#546E7A;font-size:13px;">If you didn't create a NeuroSense account, please ignore this email.</p>
      </div>
      <div style="background:#F5F9FF;padding:16px 24px;text-align:center;">
        <p style="color:#546E7A;font-size:12px;margin:0;">© 2026 NeuroSense · Stroke Awareness App</p>
      </div>
    </div>`;
  }

  private resetTemplate(name: string, tempPassword: string): string {
    return `
    <div style="font-family:Inter,sans-serif;max-width:520px;margin:auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(21,101,192,0.10);">
      <div style="background:linear-gradient(135deg,#1565C0,#1E88E5);padding:32px 24px;text-align:center;">
        <img src="cid:neurosense-logo" alt="NeuroSense" style="width:80px;height:80px;object-fit:contain;border-radius:16px;margin-bottom:16px;display:block;margin-left:auto;margin-right:auto;" />
        <h1 style="color:#fff;margin:0;font-size:24px;font-weight:700;">NeuroSense</h1>
        <p style="color:#E3F2FD;margin:4px 0 0;font-size:13px;">Password Reset</p>
      </div>
      <div style="padding:32px 24px;">
        <h2 style="color:#0D1B2A;margin:0 0 8px;">Hi ${name},</h2>
        <p style="color:#546E7A;margin:0 0 24px;">Your temporary password is below. Log in and update it immediately.</p>
        <div style="background:#F5F9FF;border:2px dashed #1E88E5;border-radius:12px;padding:20px;text-align:center;margin-bottom:24px;">
          <span style="font-size:22px;font-weight:700;letter-spacing:4px;color:#1565C0;">${tempPassword}</span>
        </div>
        <p style="color:#546E7A;font-size:13px;">If you did not request this, please contact support immediately.</p>
      </div>
      <div style="background:#F5F9FF;padding:16px 24px;text-align:center;">
        <p style="color:#546E7A;font-size:12px;margin:0;">© 2026 NeuroSense · Stroke Awareness App</p>
      </div>
    </div>`;
  }
}
