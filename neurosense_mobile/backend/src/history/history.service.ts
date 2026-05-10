import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AssessmentHistory, AssessmentHistoryDocument } from './schemas/assessment-history.schema';

@Injectable()
export class HistoryService {
  constructor(
    @InjectModel(AssessmentHistory.name)
    private readonly model: Model<AssessmentHistoryDocument>,
  ) {}

  async create(data: Partial<AssessmentHistory>): Promise<AssessmentHistory> {
    return this.model.create(data);
  }

  async findByUser(userId: string): Promise<AssessmentHistory[]> {
    return this.model.find({ userId }).sort({ createdAt: 1 }).lean();
  }
}
