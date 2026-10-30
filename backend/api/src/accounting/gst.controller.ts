import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { GstService } from './gst.service';
import { QueryGstDto } from './dto/query-report.dto';

@Controller('gst')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class GstController {
  constructor(private readonly gstService: GstService) {}

  @Get('gstr-1')
  async getGstr1(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryGstDto,
  ) {
    return this.gstService.getGstr1Summary(businessId, query);
  }

  @Get('gstr-3b')
  async getGstr3b(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryGstDto,
  ) {
    return this.gstService.getGstr3bSummary(businessId, query);
  }

  @Get('summary')
  async getTaxSummary(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryGstDto,
  ) {
    const startDate = query.startDate ? new Date(query.startDate) : undefined;
    const endDate = query.endDate ? new Date(query.endDate) : undefined;
    return this.gstService.getTaxSummary(businessId, startDate, endDate);
  }
}
