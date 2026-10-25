import { IsOptional, IsDateString, IsString } from 'class-validator';

export class QueryReportDto {
  @IsOptional()
  @IsDateString()
  asOfDate?: string;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;
}

export class QueryGstDto {
  @IsOptional()
  @IsString()
  returnPeriod?: string; // Format: YYYY-MM, e.g. "2026-10"

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;
}
