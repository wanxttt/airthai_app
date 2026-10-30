import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Optional,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, CurrentUserPayload } from '../common/decorators/current-user.decorator';
import { InvoicesService } from './invoices.service';
import { CreateInvoiceDto } from './dto/create-invoice.dto';
import { QueryInvoicesDto } from './dto/query-invoices.dto';
import { CancelInvoiceDto } from './dto/cancel-invoice.dto';
import { PdfGeneratorService } from '../workers/pdf-generator.service';
import { WorkerQueueService } from '../workers/worker-queue.service';
import { JobType } from '../workers/worker.interface';

@Controller('invoices')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class InvoicesController {
  constructor(
    private readonly invoicesService: InvoicesService,
    @Optional() private readonly pdfGenerator?: PdfGeneratorService,
    @Optional() private readonly workerQueue?: WorkerQueueService,
  ) {}

  @Get()
  async findAll(
    @CurrentUser('businessId') businessId: string,
    @Query() query: QueryInvoicesDto,
  ) {
    return this.invoicesService.findAll(businessId, query);
  }

  @Get('pdf/jobs/:jobId')
  async getPdfJobStatus(
    @CurrentUser('businessId') businessId: string,
    @Param('jobId') jobId: string,
  ) {
    if (!this.workerQueue) {
      throw new NotFoundException('Worker queue service is currently unavailable.');
    }
    const job = this.workerQueue.getJob(jobId);
    if (!job || job.businessId !== businessId) {
      throw new NotFoundException(`Job ${jobId} not found.`);
    }

    return {
      success: true,
      data: {
        jobId: job.id,
        status: job.status,
        result: job.result,
        error: job.error,
        createdAt: job.createdAt,
        processedAt: job.processedAt,
      },
    };
  }

  @Get(':id/pdf')
  async downloadPdf(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
    @Res() res: Response,
  ) {
    if (!this.pdfGenerator) {
      throw new NotFoundException('PDF generator service is currently unavailable.');
    }

    const response = await this.invoicesService.findOne(businessId, id);
    const inv = response?.data;
    if (!inv) {
      throw new NotFoundException(`Invoice ${id} not found.`);
    }

    const pdfBuffer = this.pdfGenerator.generateInvoicePdf({
      invoiceNumber: inv.invoiceNumber,
      invoiceDate: inv.invoiceDate.toISOString().split('T')[0],
      businessName: (inv as any).business?.name || 'Authorized Business',
      businessGstin: (inv as any).business?.gstin,
      businessAddress: (inv as any).business?.address,
      customerName: (inv as any).customer?.name || 'Walk-in Customer',
      customerGstin: (inv as any).customer?.gstin,
      items: (inv.items || []).map((item: any) => ({
        description: item.description,
        hsnCode: item.hsnCode,
        quantity: Number(item.quantity),
        unitPrice: Number(item.unitPrice),
        taxRate: Number(item.taxRate),
        total: Number(item.totalAmount),
      })),
      subtotal: Number(inv.subtotal),
      taxAmount: Number(inv.cgstAmount) + Number(inv.sgstAmount) + Number(inv.igstAmount) + Number(inv.cessAmount),
      totalAmount: Number(inv.totalAmount),
      notes: inv.notes || undefined,
    });

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="Invoice-${inv.invoiceNumber}.pdf"`,
      'Content-Length': pdfBuffer.length.toString(),
    });

    res.end(pdfBuffer);
  }

  @Post(':id/pdf/async')
  @HttpCode(HttpStatus.ACCEPTED)
  async queuePdfGeneration(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    if (!this.workerQueue) {
      throw new NotFoundException('Worker queue service is currently unavailable.');
    }

    const response = await this.invoicesService.findOne(businessId, id);
    const inv = response?.data;
    if (!inv) {
      throw new NotFoundException(`Invoice ${id} not found.`);
    }

    const correlationId = (req as any)?.requestId || (req.headers?.['x-request-id'] as string) || undefined;

    const job = await this.workerQueue.enqueue(
      businessId,
      JobType.GENERATE_INVOICE_PDF,
      {
        invoiceNumber: inv.invoiceNumber,
        invoiceDate: inv.invoiceDate.toISOString().split('T')[0],
        businessName: (inv as any).business?.name || 'Authorized Business',
        businessGstin: (inv as any).business?.gstin,
        customerName: (inv as any).customer?.name || 'Walk-in Customer',
        customerGstin: (inv as any).customer?.gstin,
        items: (inv.items || []).map((item: any) => ({
          description: item.description,
          hsnCode: item.hsnCode,
          quantity: Number(item.quantity),
          unitPrice: Number(item.unitPrice),
          taxRate: Number(item.taxRate),
          total: Number(item.totalAmount),
        })),
        subtotal: Number(inv.subtotal),
        taxAmount: Number(inv.cgstAmount) + Number(inv.sgstAmount) + Number(inv.igstAmount) + Number(inv.cessAmount),
        totalAmount: Number(inv.totalAmount),
        notes: inv.notes || undefined,
      },
      3,
      undefined,
      correlationId,
    );

    return {
      success: true,
      statusCode: HttpStatus.ACCEPTED,
      data: {
        jobId: job.id,
        status: job.status,
      },
    };
  }

  @Get(':id')
  async findOne(
    @CurrentUser('businessId') businessId: string,
    @Param('id') id: string,
  ) {
    return this.invoicesService.findOne(businessId, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateInvoiceDto,
  ) {
    return this.invoicesService.create(user.businessId, dto, user.id);
  }

  @Patch(':id/cancel')
  @Roles('OWNER', 'ADMIN')
  async cancel(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: CancelInvoiceDto,
  ) {
    return this.invoicesService.cancel(user.businessId, id, dto, user.id);
  }
}
