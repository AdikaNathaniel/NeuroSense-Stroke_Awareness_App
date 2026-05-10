import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { HistoryController } from './history.controller';
import { HistoryService } from './history.service';
import { AssessmentHistory, AssessmentHistorySchema } from './schemas/assessment-history.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: AssessmentHistory.name, schema: AssessmentHistorySchema },
    ]),
  ],
  controllers: [HistoryController],
  providers: [HistoryService],
  exports: [HistoryService],
})
export class HistoryModule {}
