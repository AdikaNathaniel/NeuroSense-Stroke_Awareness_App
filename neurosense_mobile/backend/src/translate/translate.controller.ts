import { Body, Controller, Post } from '@nestjs/common';
import { TranslateService } from './translate.service';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsString } from 'class-validator';

export class TranslateDto {
  @IsArray()
  @IsString({ each: true })
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  texts!: string[];

  @IsString()
  targetLanguage!: string;
}

@Controller('api/v1/translate')
export class TranslateController {
  constructor(private readonly translateService: TranslateService) {}

  // Intentionally public (no JwtAuthGuard) so the language picker can be used
  // on the register page before the user is logged in.
  @Post()
  async translate(@Body() dto: TranslateDto) {
    const translations = await this.translateService.translate(dto.texts, dto.targetLanguage);
    return { translations };
  }
}
