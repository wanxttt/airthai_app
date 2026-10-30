import { ConfigService } from '@nestjs/config';
import { WorkerQueueService } from './worker-queue.service';
import { PdfGeneratorService } from './pdf-generator.service';
import { JobType } from './worker.interface';

describe('WorkerQueueService & PdfGeneratorService', () => {
  let queueService: WorkerQueueService;
  let pdfGenerator: PdfGeneratorService;
  let configService: ConfigService;

  beforeEach(() => {
    configService = {
      get: jest.fn().mockReturnValue(false),
    } as any;
    pdfGenerator = new PdfGeneratorService();
    queueService = new WorkerQueueService(configService, pdfGenerator);
  });

  afterEach(() => {
    queueService.onModuleDestroy();
  });

  describe('PdfGeneratorService', () => {
    it('generates a valid binary PDF buffer with header and trailer', () => {
      const buffer = pdfGenerator.generateInvoicePdf({
        invoiceNumber: 'INV-2026-001',
        invoiceDate: '2026-10-30',
        businessName: 'Apex Industrial Tools',
        businessGstin: '27AABCU9603R1ZM',
        customerName: 'BuildCorp Infra',
        items: [
          {
            description: 'Rotary Hammer Drill',
            hsnCode: '8467',
            quantity: 2,
            unitPrice: 4500,
            taxRate: 18,
            total: 9000,
          },
        ],
        subtotal: 9000,
        taxAmount: 1620,
        totalAmount: 10620,
      });

      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(100);

      const str = buffer.toString('binary');
      expect(str.startsWith('%PDF-1.4')).toBe(true);
      expect(str).toContain('%%EOF');
      expect(str).toContain('INV-2026-001');
      expect(str).toContain('Apex Industrial Tools');
    });
  });

  describe('WorkerQueueService', () => {
    it('enqueues and executes background jobs asynchronously', async () => {
      const payload = {
        invoiceNumber: 'INV-TEST-99',
        invoiceDate: '2026-10-30',
        businessName: 'AirthAI Test MSME',
        customerName: 'Test Buyer',
        items: [
          {
            description: 'Test Item',
            quantity: 1,
            unitPrice: 100,
            taxRate: 18,
            total: 100,
          },
        ],
        subtotal: 100,
        taxAmount: 18,
        totalAmount: 118,
      };

      const job = await queueService.enqueue('biz_test_01', JobType.GENERATE_INVOICE_PDF, payload);
      expect(job.id).toBeDefined();
      expect(job.status).toBe('PENDING');

      // Wait briefly for worker queue processor loop to execute
      await new Promise((resolve) => setTimeout(resolve, 400));

      const processedJob = queueService.getJob(job.id);
      expect(processedJob).not.toBeNull();
      expect(processedJob?.status).toBe('COMPLETED');
      expect(processedJob?.result).toBeDefined();
      expect(processedJob?.result.contentType).toBe('application/pdf');
      expect(processedJob?.result.byteLength).toBeGreaterThan(0);
    });

    it('returns null for nonexistent jobs', () => {
      expect(queueService.getJob('nonexistent_job')).toBeNull();
    });

    it('deduplicates in-flight jobs when matching jobKey is provided', async () => {
      // Pause queue loop by destroying timer so jobs stay PENDING
      queueService.onModuleDestroy();

      const job1 = await queueService.enqueue('biz_dup', JobType.GENERATE_REPORT_PDF, { report: 'sales' }, 3, 'dedup_key_1');
      const job2 = await queueService.enqueue('biz_dup', JobType.GENERATE_REPORT_PDF, { report: 'sales' }, 3, 'dedup_key_1');

      expect(job1.id).toBe(job2.id);
      expect(job2.status).toBe('PENDING');
    });

    it('prunes expired completed jobs from memory', async () => {
      queueService.onModuleDestroy(); // keep deterministic
      const job = await queueService.enqueue('biz_prune', JobType.SYNC_BATCH_REPLAY, {});
      job.status = 'COMPLETED';
      // Fake completion date to 2 hours ago
      job.processedAt = new Date(Date.now() - 2 * 60 * 60 * 1000);

      // Enqueue a new job which triggers pruneOldJobs
      await queueService.enqueue('biz_prune', JobType.SYNC_BATCH_REPLAY, {});

      expect(queueService.getJob(job.id)).toBeNull();
    });

    it('preserves correlationId across job lifecycle', async () => {
      queueService.onModuleDestroy();
      const job = await queueService.enqueue(
        'biz_corr',
        JobType.SYNC_BATCH_REPLAY,
        {},
        3,
        undefined,
        'req_trace_corr_98765',
      );

      expect(job.correlationId).toBe('req_trace_corr_98765');
      const retrieved = queueService.getJob(job.id);
      expect(retrieved?.correlationId).toBe('req_trace_corr_98765');
    });
  });
});

