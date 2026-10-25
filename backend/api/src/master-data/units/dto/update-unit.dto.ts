import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateUnitDto {
  @IsString()
  @IsOptional()
  @MaxLength(50)
  name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  symbol?: string;
}

