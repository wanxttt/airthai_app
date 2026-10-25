import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  Min,
  IsArray,
  ValidateNested,
  ArrayMinSize,
  IsDateString,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateLedgerEntryDto {
  @IsString()
  @IsNotEmpty()
  accountId!: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  debit?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  credit?: number;
}

export class CreateJournalEntryDto {
  @IsOptional()
  @IsDateString()
  date?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  narration!: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  referenceType?: string;

  @IsOptional()
  @IsString()
  referenceId?: string;

  @IsArray()
  @ArrayMinSize(2, { message: 'Journal entry must contain at least 2 ledger lines' })
  @ValidateNested({ each: true })
  @Type(() => CreateLedgerEntryDto)
  entries!: CreateLedgerEntryDto[];
}
