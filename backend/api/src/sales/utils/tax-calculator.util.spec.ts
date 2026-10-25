import { TaxCalculatorUtil } from './tax-calculator.util';
import { Prisma } from '@prisma/client';

describe('TaxCalculatorUtil', () => {
  describe('determineIsInterState', () => {
    it('returns false for matching state codes (intra-state)', () => {
      expect(TaxCalculatorUtil.determineIsInterState('27', '27')).toBe(false);
      expect(TaxCalculatorUtil.determineIsInterState('27', '27AABCA1234A1Z5')).toBe(false);
    });

    it('returns true for different state codes (inter-state)', () => {
      expect(TaxCalculatorUtil.determineIsInterState('27', '24')).toBe(true);
      expect(TaxCalculatorUtil.determineIsInterState('27', '07AAAAA0000A1Z5')).toBe(true);
    });

    it('defaults to false if businessStateCode or placeOfSupply is missing', () => {
      expect(TaxCalculatorUtil.determineIsInterState(null, '27')).toBe(false);
      expect(TaxCalculatorUtil.determineIsInterState('27', null)).toBe(false);
    });
  });

  describe('calculateInvoice', () => {
    it('calculates intra-state GST (50% CGST and 50% SGST) correctly', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        businessStateCode: '27',
        placeOfSupply: '27',
        items: [
          {
            description: 'Item A',
            quantity: 2,
            unitPrice: 1000,
            gstRate: 18,
          },
        ],
      });

      expect(result.isInterState).toBe(false);
      expect(result.subtotal.toString()).toBe('2000');
      expect(result.taxableAmount.toString()).toBe('2000');
      expect(result.cgstAmount.toString()).toBe('180');
      expect(result.sgstAmount.toString()).toBe('180');
      expect(result.igstAmount.toString()).toBe('0');
      expect(result.cessAmount.toString()).toBe('0');
      expect(result.totalAmount.toString()).toBe('2360');
      expect(result.roundOff.toString()).toBe('0');
    });

    it('calculates inter-state GST (100% IGST) correctly', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        businessStateCode: '27',
        placeOfSupply: '24', // Gujarat
        items: [
          {
            description: 'Item B',
            quantity: 5,
            unitPrice: 200,
            gstRate: 12,
          },
        ],
      });

      expect(result.isInterState).toBe(true);
      expect(result.subtotal.toString()).toBe('1000');
      expect(result.taxableAmount.toString()).toBe('1000');
      expect(result.cgstAmount.toString()).toBe('0');
      expect(result.sgstAmount.toString()).toBe('0');
      expect(result.igstAmount.toString()).toBe('120');
      expect(result.totalAmount.toString()).toBe('1120');
    });

    it('calculates line-level discounts and invoice-level discounts', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        businessStateCode: '27',
        placeOfSupply: '27',
        invoiceDiscountAmount: 50,
        items: [
          {
            description: 'Item C',
            quantity: 1,
            unitPrice: 500,
            discountAmount: 50, // taxable = 450
            gstRate: 18, // 450 * 18% = 81 (40.50 CGST + 40.50 SGST)
          },
        ],
      });

      expect(result.subtotal.toString()).toBe('500');
      expect(result.discountAmount.toString()).toBe('100'); // 50 line + 50 invoice
      expect(result.taxableAmount.toString()).toBe('400'); // 450 - 50
      expect(result.cgstAmount.toString()).toBe('40.5');
      expect(result.sgstAmount.toString()).toBe('40.5');
      // total = 400 + 81 = 481
      expect(result.totalAmount.toString()).toBe('481');
    });

    it('supports non-GST invoices where enableGst is false', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        enableGst: false,
        placeOfSupply: '27',
        items: [
          {
            description: 'Non-GST Product',
            quantity: 3,
            unitPrice: 150,
            gstRate: 18,
          },
        ],
      });

      expect(result.subtotal.toString()).toBe('450');
      expect(result.taxableAmount.toString()).toBe('450');
      expect(result.cgstAmount.toString()).toBe('0');
      expect(result.sgstAmount.toString()).toBe('0');
      expect(result.igstAmount.toString()).toBe('0');
      expect(result.totalAmount.toString()).toBe('450');
    });

    it('calculates cess when applicable', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        businessStateCode: '27',
        placeOfSupply: '27',
        items: [
          {
            description: 'Automobile Part',
            quantity: 1,
            unitPrice: 1000,
            gstRate: 28,
            cessRate: 12,
          },
        ],
      });

      expect(result.cgstAmount.toString()).toBe('140');
      expect(result.sgstAmount.toString()).toBe('140');
      expect(result.cessAmount.toString()).toBe('120');
      expect(result.totalAmount.toString()).toBe('1400');
    });

    it('calculates exact commercial half-up round-off', () => {
      const result = TaxCalculatorUtil.calculateInvoice({
        businessStateCode: '27',
        placeOfSupply: '27',
        items: [
          {
            description: 'Odd Price Item',
            quantity: 1,
            unitPrice: 100.33,
            gstRate: 18, // tax = 18.06 (9.03 + 9.03) -> rawTotal = 118.39
          },
        ],
      });

      expect(result.taxableAmount.toString()).toBe('100.33');
      expect(result.cgstAmount.toString()).toBe('9.03');
      expect(result.sgstAmount.toString()).toBe('9.03');
      // raw total = 100.33 + 18.06 = 118.39
      // rounded = 118.00
      // roundOff = -0.39
      expect(result.roundOff.toString()).toBe('-0.39');
      expect(result.totalAmount.toString()).toBe('118');
    });
  });
});
