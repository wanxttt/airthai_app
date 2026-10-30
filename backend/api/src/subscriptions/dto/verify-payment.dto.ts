import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyPaymentDto {
  @IsString()
  @IsNotEmpty()
  providerOrderId!: string;

  @IsString()
  @IsNotEmpty()
  providerPaymentId!: string;

  @IsString()
  @IsNotEmpty()
  providerSignature!: string;
}

