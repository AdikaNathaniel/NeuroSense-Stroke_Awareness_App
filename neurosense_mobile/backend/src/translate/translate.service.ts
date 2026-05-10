import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class TranslateService {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  constructor(private config: ConfigService) {
    this.apiKey = this.config.get<string>('OPENROUTER_API_KEY') ?? '';
    this.model  = this.config.get<string>('OPENROUTER_MODEL') ?? 'anthropic/claude-3.5-haiku';
  }

  async translate(texts: string[], targetLanguage: string): Promise<string[]> {
    if (!this.apiKey) {
      throw new HttpException('OpenRouter API key not configured.', HttpStatus.SERVICE_UNAVAILABLE);
    }
    if (targetLanguage === 'English' || targetLanguage === 'en') {
      return texts;
    }

    const systemPrompt =
      'You are a professional UI translator. You always respond with ONLY a valid JSON array of translated strings — same length and order as the input array. No commentary, no code fences, no extra text. Preserve placeholders, punctuation, line breaks, and units verbatim.';

    const userPrompt = `Translate the following ${texts.length} UI strings into ${targetLanguage}. Return the JSON array only.\n\nInput JSON:\n${JSON.stringify(texts)}`;

    const payload = {
      model: this.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user',   content: userPrompt },
      ],
      max_tokens: 4096,
      temperature: 0.2,
    };

    const res = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type':  'application/json',
        'HTTP-Referer':  'https://neurosense.app',
        'X-Title':       'NeuroSense',
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new HttpException(`OpenRouter error: ${err}`, HttpStatus.BAD_GATEWAY);
    }

    const data = (await res.json()) as any;
    const raw  = (data?.choices?.[0]?.message?.content ?? '').trim();

    // Pull out the first JSON array even if the model wraps it in code fences.
    const match = raw.match(/\[[\s\S]*\]/);
    if (!match) {
      throw new HttpException('Translator returned no JSON array.', HttpStatus.BAD_GATEWAY);
    }
    let translations: string[];
    try {
      translations = JSON.parse(match[0]);
    } catch (e) {
      throw new HttpException(`Translator JSON was malformed: ${(e as Error).message}`, HttpStatus.BAD_GATEWAY);
    }
    if (!Array.isArray(translations) || translations.some(t => typeof t !== 'string')) {
      throw new HttpException('Translator response is not a string array.', HttpStatus.BAD_GATEWAY);
    }
    if (translations.length !== texts.length) {
      throw new HttpException(
        `Translation count mismatch (got ${translations.length}, expected ${texts.length}).`,
        HttpStatus.BAD_GATEWAY,
      );
    }
    return translations;
  }
}
