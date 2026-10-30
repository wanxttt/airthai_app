import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class QueryCopilotDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  query: string;

  @IsString()
  @IsOptional()
  period?: string;
}

