import { IsEnum, IsOptional, IsString, Matches } from 'class-validator';
import { BillFormat, TaxType } from '@prisma/client';

export class BusinessSetupDto {
  @IsOptional()
  @IsString()
  businessName?: string;

  @IsOptional()
  @IsString()
  legalName?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/, {
    message: 'Invalid Indian GSTIN format (15 characters: e.g. 27AAAAA0000A1Z5).',
  })
  gstin?: string;

  @IsOptional()
  @IsString()
  pan?: string;

  @IsOptional()
  @IsString()
  addressLine1?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  state?: string;

  @IsOptional()
  @IsString()
  stateCode?: string;

  @IsOptional()
  @IsString()
  pincode?: string;

  @IsOptional()
  @IsEnum(TaxType)
  taxType?: TaxType;

  @IsOptional()
  @IsEnum(BillFormat)
  defaultBillFormat?: BillFormat;
}
