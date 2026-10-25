import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CancelInvoiceDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  reason!: string;
}
