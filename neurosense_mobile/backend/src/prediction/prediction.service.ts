import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class PredictionService {
  constructor(private config: ConfigService) {}

  async predict(features: Record<string, any>) {
    const mlUrl = this.config.get<string>('ML_SERVICE_URL');
    try {
      const { data } = await axios.post(`${mlUrl}/predict`, features, { timeout: 10000 });
      return {
        probability: data.probability,
        riskBand: this.getRiskBand(data.probability),
        recommendation: this.getRecommendation(data.probability),
      };
    } catch {
      throw new ServiceUnavailableException('Prediction service is currently unavailable.');
    }
  }

  private getRiskBand(probability: number): string {
    if (probability < 0.25) return 'LOW';
    if (probability < 0.50) return 'MEDIUM';
    if (probability < 0.75) return 'HIGH';
    return 'CRITICAL';
  }

  private getRecommendation(probability: number): string {
    if (probability < 0.25)
      return 'Your stroke risk is low. Keep up healthy habits: stay active, eat well, and avoid smoking.';
    if (probability < 0.50)
      return 'You have a moderate risk. Consider lifestyle changes: reduce salt intake, exercise regularly, and monitor your blood pressure.';
    if (probability < 0.75)
      return 'Your risk is high. Please consult your GP soon to discuss your cardiovascular health and risk factors.';
    return 'Critical risk detected. Please seek medical attention immediately or call emergency services.';
  }
}
