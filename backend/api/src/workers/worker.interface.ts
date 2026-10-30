export enum JobType {
  GENERATE_INVOICE_PDF = 'GENERATE_INVOICE_PDF',
  GENERATE_REPORT_PDF = 'GENERATE_REPORT_PDF',
  SYNC_BATCH_REPLAY = 'SYNC_BATCH_REPLAY',
}

export type JobStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

export interface JobRecord<T = any, R = any> {
  id: string;
  type: JobType;
  businessId: string;
  jobKey?: string;
  correlationId?: string;
  payload: T;
  status: JobStatus;
  attempts: number;
  maxAttempts: number;
  result?: R;
  error?: string;
  createdAt: Date;
  processedAt?: Date;
}

