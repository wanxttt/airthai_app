import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CancelPurchaseDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  reason!: string;
}
