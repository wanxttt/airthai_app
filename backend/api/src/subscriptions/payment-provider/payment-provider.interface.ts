export interface CreateOrderParams {
  businessId: string;
  planId: string;
  planName: string;
  amountInPaise: number;
  currency: string;
  receipt: string;
  notes?: Record<string, string>;
}

export interface ProviderOrderResult {
  providerOrderId: string;
  amountInPaise: number;
  currency: string;
  receipt: string;
  status: string;
  keyId?: string;
}

export interface VerifyPaymentParams {
  providerOrderId: string;
  providerPaymentId: string;
  providerSignature: string;
}

export interface IPaymentProvider {
  readonly providerName: string;
  createOrder(params: CreateOrderParams): Promise<ProviderOrderResult>;
  verifyPaymentSignature(params: VerifyPaymentParams): boolean;
  verifyWebhookSignature(rawBody: string | Buffer, signature: string): boolean;
}

