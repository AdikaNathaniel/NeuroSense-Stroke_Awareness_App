import { Controller, Get, Request, UseGuards } from '@nestjs/common';
import { HistoryService } from './history.service';
import { JwtAuthGuard } from '../shared/guards/jwt-auth.guard';

@Controller('api/v1/history')
export class HistoryController {
  constructor(private readonly historyService: HistoryService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMyHistory(@Request() req: any) {
    return this.historyService.findByUser(req.user.userId);
  }
}
