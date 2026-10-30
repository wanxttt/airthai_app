import { Injectable, Logger } from '@nestjs/common';

export interface InvoicePdfData {
  invoiceNumber: string;
  invoiceDate: string;
  businessName: string;
  businessGstin?: string;
  businessAddress?: string;
  customerName: string;
  customerGstin?: string;
  items: Array<{
    description: string;
    hsnCode?: string;
    quantity: number;
    unitPrice: number;
    taxRate: number;
    total: number;
  }>;
  subtotal: number;
  taxAmount: number;
  totalAmount: number;
  notes?: string;
}

@Injectable()
export class PdfGeneratorService {
  private readonly logger = new Logger(PdfGeneratorService.name);

  /**
   * Generates a deterministic, standard-compliant PDF-1.4 buffer for an invoice.
   * Zero external OS or binary dependencies.
   */
  generateInvoicePdf(data: InvoicePdfData): Buffer {
    const textLines: string[] = [
      `TAX INVOICE`,
      `--------------------------------------------------------------------------------`,
      `Invoice #: ${data.invoiceNumber}               Date: ${data.invoiceDate}`,
      `Seller:    ${data.businessName} ${data.businessGstin ? `(GSTIN: ${data.businessGstin})` : ''}`,
      `Customer:  ${data.customerName} ${data.customerGstin ? `(GSTIN: ${data.customerGstin})` : ''}`,
      `--------------------------------------------------------------------------------`,
      `Item Description           HSN/SAC    Qty     Rate        Tax%     Amount`,
      `--------------------------------------------------------------------------------`,
    ];

    for (const item of data.items) {
      const desc = item.description.padEnd(26).substring(0, 26);
      const hsn = (item.hsnCode || '-').padEnd(10).substring(0, 10);
      const qty = item.quantity.toString().padStart(6);
      const rate = item.unitPrice.toFixed(2).padStart(11);
      const tax = `${item.taxRate}%`.padStart(8);
      const amt = item.total.toFixed(2).padStart(12);
      textLines.push(`${desc} ${hsn} ${qty} ${rate} ${tax} ${amt}`);
    }

    textLines.push(`--------------------------------------------------------------------------------`);
    textLines.push(`Subtotal:                                            Rs. ${data.subtotal.toFixed(2)}`);
    textLines.push(`Total GST:                                           Rs. ${data.taxAmount.toFixed(2)}`);
    textLines.push(`Grand Total:                                         Rs. ${data.totalAmount.toFixed(2)}`);
    textLines.push(`--------------------------------------------------------------------------------`);
    if (data.notes) {
      textLines.push(`Notes: ${data.notes}`);
    }
    textLines.push(`Authorized Signatory: ${data.businessName}`);

    return this.buildPdfDocument(textLines);
  }

  /**
   * Low-level PDF-1.4 stream builder.
   */
  private buildPdfDocument(lines: string[]): Buffer {
    let streamContent = 'BT\n/F1 10 Tf\n14 TL\n40 780 Td\n';

    for (let i = 0; i < lines.length; i++) {
      const safeLine = lines[i]
        .replace(/\\/g, '\\\\')
        .replace(/\(/g, '\\(')
        .replace(/\)/g, '\\)');
      
      if (i === 0) {
        streamContent += `/F1 14 Tf\n(${safeLine}) Tj\n/F1 9 Tf\nT*\nT*\n`;
      } else {
        streamContent += `(${safeLine}) Tj\nT*\n`;
      }
    }
    streamContent += 'ET\n';

    const streamLength = Buffer.byteLength(streamContent, 'utf8');

    const objects: string[] = [];
    objects.push(`1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n`);
    objects.push(`2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n`);
    objects.push(
      `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n`,
    );
    objects.push(`4 0 obj\n<< /Length ${streamLength} >>\nstream\n${streamContent}endstream\nendobj\n`);
    objects.push(`5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n`);

    let pdf = `%PDF-1.4\n%\xE2\xE3\xCF\xD3\n`;
    const offsets: number[] = [0];

    for (const obj of objects) {
      offsets.push(Buffer.byteLength(pdf, 'utf8'));
      pdf += obj;
    }

    const startXref = Buffer.byteLength(pdf, 'utf8');
    pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;

    for (let i = 1; i <= objects.length; i++) {
      const off = offsets[i].toString().padStart(10, '0');
      pdf += `${off} 00000 n \n`;
    }

    pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${startXref}\n%%EOF\n`;

    return Buffer.from(pdf, 'binary');
  }
}

