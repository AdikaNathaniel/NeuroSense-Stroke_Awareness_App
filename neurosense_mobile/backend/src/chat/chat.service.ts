import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const SYSTEM_PROMPT = `You are NeuroSense AI, a helpful stroke awareness and brain health assistant.
You help users understand stroke risk factors, symptoms, prevention, and the FAST acronym (Face drooping, Arm weakness, Speech difficulty, Time to call emergency services).
You can answer questions about hypertension, diabetes, heart disease, smoking, BMI, cholesterol, and how they relate to stroke risk.
You provide clear, empathetic, medically accurate responses suitable for general public education.
You ALWAYS recommend consulting a doctor for personal medical advice or emergencies.
If someone describes active stroke symptoms, immediately urge them to call emergency services (911 or local equivalent).
Keep answers concise and easy to understand. Do not use excessive medical jargon.`;

@Injectable()
export class ChatService {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  constructor(private config: ConfigService) {
    this.apiKey = this.config.get<string>('OPENROUTER_API_KEY') ?? '';
    this.model  = this.config.get<string>('OPENROUTER_MODEL') ?? 'anthropic/claude-3.5-haiku';
  }

  async chat(messages: { role: string; content: string }[]): Promise<string> {
    if (!this.apiKey || this.apiKey === 'PASTE_YOUR_OPENROUTER_API_KEY_HERE') {
      throw new HttpException('OpenRouter API key not configured.', HttpStatus.SERVICE_UNAVAILABLE);
    }

    const payload = {
      model: this.model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        ...messages,
      ],
      max_tokens: 512,
      temperature: 0.7,
    };

    const res = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://neurosense.app',
        'X-Title': 'NeuroSense',
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new HttpException(`OpenRouter error: ${err}`, HttpStatus.BAD_GATEWAY);
    }

    const data = await res.json() as any;
    return data.choices?.[0]?.message?.content ?? 'Sorry, I could not generate a response.';
  }
}
