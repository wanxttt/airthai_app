import { Injectable, Logger, OnModuleDestroy, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JobRecord, JobStatus, JobType } from './worker.interface';
import { PdfGeneratorService } from './pdf-generator.service';
import { TelemetryService } from '../common/monitoring/telemetry.service';

@Injectable()
export class WorkerQueueService implements OnModuleDestroy {
  private readonly logger = new Logger(WorkerQueueService.name);
  private readonly jobs = new Map<string, JobRecord>();
  private readonly queue: string[] = [];
  private isProcessing = false;
  private intervalId: NodeJS.Timeout | null = null;

  constructor(
    private readonly configService: ConfigService,
    private readonly pdfGenerator: PdfGeneratorService,
    @Optional() private readonly telemetry?: TelemetryService,
  ) {
    // Start local worker consumer loop
    this.intervalId = setInterval(() => this.processNext(), 200);
  }

  /**
   * Enqueues an asynchronous background job with deduplication support.
   */
  async enqueue<T>(
    businessId: string,
    type: JobType,
    payload: T,
    maxAttempts = 3,
    jobKey?: string,
    correlationId?: string,
  ): Promise<JobRecord<T>> {
    this.pruneOldJobs();

    if (jobKey) {
      for (const existing of this.jobs.values()) {
        if (
          existing.businessId === businessId &&
          existing.jobKey === jobKey &&
          (existing.status === 'PENDING' || existing.status === 'PROCESSING')
        ) {
          this.logger.log(`Reusing in-flight job ${existing.id} for jobKey ${jobKey}`);
          return existing as JobRecord<T>;
        }
      }
    }

    const id = `job_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const record: JobRecord<T> = {
      id,
      type,
      businessId,
      jobKey,
      correlationId,
      payload,
      status: 'PENDING',
      attempts: 0,
      maxAttempts,
      createdAt: new Date(),
    };

    this.jobs.set(id, record);
    this.queue.push(id);
    this.telemetry?.recordJobEnqueued();
    const corrStr = correlationId ? ` [corr:${correlationId}]` : '';
    this.logger.log(`Enqueued job ${id}${corrStr} [${type}] for business ${businessId}`);
    return record;
  }

  /**
   * Prunes terminal jobs (COMPLETED or FAILED) to prevent memory leaks.
   */
  private pruneOldJobs(maxJobs = 1000, maxAgeMs = 60 * 60 * 1000): void {
    const now = Date.now();
    for (const [id, job] of this.jobs.entries()) {
      if (job.status === 'COMPLETED' || job.status === 'FAILED') {
        const age = now - (job.processedAt ? job.processedAt.getTime() : job.createdAt.getTime());
        if (age > maxAgeMs) {
          this.jobs.delete(id);
        }
      }
    }

    if (this.jobs.size > maxJobs) {
      for (const [id, job] of this.jobs.entries()) {
        if (job.status === 'COMPLETED' || job.status === 'FAILED') {
          this.jobs.delete(id);
          if (this.jobs.size <= maxJobs) break;
        }
      }
    }
  }

  /**
   * Checks current status and result of a job.
   */
  getJob(jobId: string): JobRecord | null {
    return this.jobs.get(jobId) || null;
  }

  /**
   * Processes the next job in the worker queue.
   */
  private async processNext(): Promise<void> {
    if (this.isProcessing || this.queue.length === 0) return;
    this.isProcessing = true;

    const jobId = this.queue.shift();
    if (!jobId) {
      this.isProcessing = false;
      return;
    }

    const job = this.jobs.get(jobId);
    if (!job || job.status !== 'PENDING') {
      this.isProcessing = false;
      return;
    }

    job.status = 'PROCESSING';
    job.attempts += 1;

    try {
      let result: any;
      switch (job.type) {
        case JobType.GENERATE_INVOICE_PDF:
          result = this.pdfGenerator.generateInvoicePdf(job.payload);
          // Store base64 representation or byte length for status reporting
          job.result = {
            contentType: 'application/pdf',
            byteLength: result.length,
            base64: result.toString('base64'),
          };
          break;

        case JobType.SYNC_BATCH_REPLAY:
        case JobType.GENERATE_REPORT_PDF:
        default:
          job.result = { success: true };
          break;
      }

      job.status = 'COMPLETED';
      job.processedAt = new Date();
      this.telemetry?.recordJobCompleted();
      const corrStr = job.correlationId ? ` [corr:${job.correlationId}]` : '';
      this.logger.log(`Job ${job.id}${corrStr} [${job.type}] completed successfully.`);
    } catch (err: any) {
      this.telemetry?.recordJobFailed();
      const corrStr = job.correlationId ? ` [corr:${job.correlationId}]` : '';
      this.logger.error(`Job ${job.id}${corrStr} failed on attempt ${job.attempts}: ${err.message}`);
      if (job.attempts < job.maxAttempts) {
        job.status = 'PENDING';
        this.queue.push(job.id); // Re-queue for retry
      } else {
        job.status = 'FAILED';
        job.error = err.message;
        job.processedAt = new Date();
      }
    } finally {
      this.isProcessing = false;
    }
  }

  onModuleDestroy(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }
}

