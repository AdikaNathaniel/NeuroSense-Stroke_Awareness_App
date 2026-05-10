import { Module } from '@nestjs/common';
import { PredictionController } from './prediction.controller';
import { PredictionService } from './prediction.service';
import { HistoryModule } from '../history/history.module';

@Module({
  imports: [HistoryModule],
  controllers: [PredictionController],
  providers: [PredictionService],
})
export class PredictionModule {}
