import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type AssessmentHistoryDocument = AssessmentHistory & Document;

@Schema({ timestamps: true })
export class AssessmentHistory {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @Prop() gender: string;
  @Prop() age: number;
  @Prop() hypertension: number;
  @Prop() heart_disease: number;
  @Prop() ever_married: string;
  @Prop() work_type: string;
  @Prop() residence_type: string;
  @Prop() avg_glucose_level: number;
  @Prop() bmi: number;
  @Prop() smoking_status: string;
  @Prop({ required: true }) probability: number;
  @Prop({ required: true }) riskBand: string;
}

export const AssessmentHistorySchema = SchemaFactory.createForClass(AssessmentHistory);
