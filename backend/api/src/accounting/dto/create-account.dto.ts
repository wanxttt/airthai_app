import { IsString, IsNotEmpty, IsEnum, IsOptional, IsNumber, MaxLength } from 'class-validator';
import { AccountType } from '@prisma/client';

export class CreateAccountDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name!: string;

  @IsEnum(AccountType)
  type!: AccountType;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  openingBalance?: number;
}
