import { Body, Controller, Post, Request, UseGuards } from '@nestjs/common';
import { PredictionService } from './prediction.service';
import { HistoryService } from '../history/history.service';
import { JwtAuthGuard } from '../shared/guards/jwt-auth.guard';

export class PredictDto {
  gender!: string;
  age!: number;
  hypertension!: number;
  heart_disease!: number;
  ever_married!: string;
  work_type!: string;
  residence_type!: string;
  avg_glucose_level!: number;
  bmi!: number;
  smoking_status!: string;
}

@Controller('api/v1/predict')
export class PredictionController {
  constructor(
    private readonly predictionService: PredictionService,
    private readonly historyService: HistoryService,
  ) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async predict(@Body() dto: PredictDto, @Request() req: any) {
    const result = await this.predictionService.predict(dto);
    // Auto-save to user history (fire-and-forget, never blocks the response)
    this.historyService.create({
      userId: req.user.userId,
      ...dto,
      probability: result.probability,
      riskBand: result.riskBand,
    }).catch(() => {});
    return result;
  }
}
