import { Prisma } from '@prisma/client';

export type Decimal = Prisma.Decimal;
const Decimal = Prisma.Decimal;

export interface CalculateLineItemInput {
  productId?: string;
  variantId?: string;
  description: string;
  hsnCode?: string;
  quantity: number | string | Decimal;
  unitPrice: number | string | Decimal;
  discountAmount?: number | string | Decimal;
  gstRate?: number | string | Decimal;
  cessRate?: number | string | Decimal;
}

export interface CalculatedLineItem {
  productId?: string;
  variantId?: string;
  description: string;
  hsnCode?: string;
  quantity: Decimal;
  unitPrice: Decimal;
  grossAmount: Decimal;
  discountAmount: Decimal;
  taxableAmount: Decimal;
  gstRate: Decimal;
  cgstAmount: Decimal;
  sgstAmount: Decimal;
  igstAmount: Decimal;
  cessAmount: Decimal;
  totalAmount: Decimal;
}

export interface TaxCalculationInput {
  items: CalculateLineItemInput[];
  businessStateCode?: string | null;
  placeOfSupply: string;
  isInterState?: boolean;
  enableGst?: boolean;
  invoiceDiscountAmount?: number | string | Decimal;
  isReverseCharge?: boolean;
}

export interface CalculatedInvoiceTotals {
  isInterState: boolean;
  placeOfSupply: string;
  items: CalculatedLineItem[];
  subtotal: Decimal;
  discountAmount: Decimal;
  taxableAmount: Decimal;
  cgstAmount: Decimal;
  sgstAmount: Decimal;
  igstAmount: Decimal;
  cessAmount: Decimal;
  taxAmount: Decimal;
  roundOff: Decimal;
  totalAmount: Decimal;
}

export class TaxCalculatorUtil {
  /**
   * Determine whether a transaction is inter-state based on business state and place of supply.
   * State codes in India are 2-digit numbers (e.g., '27' for Maharashtra, '07' for Delhi).
   * If place of supply matches business state code, it's intra-state (isInterState = false).
   */
  public static determineIsInterState(
    businessStateCode?: string | null,
    placeOfSupply?: string | null,
  ): boolean {
    if (!businessStateCode || !placeOfSupply) {
      return false; // Default to intra-state if unspecified
    }

    const cleanBiz = businessStateCode.trim().toLowerCase();
    const cleanPos = placeOfSupply.trim().toLowerCase();

    // Direct match (either by 2-digit code or name)
    if (cleanBiz === cleanPos) {
      return false;
    }

    // If placeOfSupply contains state code at start (e.g. GSTIN first 2 digits)
    if (cleanBiz.length === 2 && cleanPos.startsWith(cleanBiz)) {
      return false;
    }

    return true;
  }

  /**
   * Authoritatively calculate all line-level and invoice-level taxes, subtotals, round-off, and grand total.
   * Uses exact arbitrary-precision arithmetic (Decimal.js / Prisma.Decimal).
   */
  public static calculateInvoice(input: TaxCalculationInput): CalculatedInvoiceTotals {
    const enableGst = input.enableGst !== false;
    const isInterState =
      input.isInterState !== undefined
        ? input.isInterState
        : this.determineIsInterState(input.businessStateCode, input.placeOfSupply);

    let sumGross = new Decimal(0);
    let sumLineDiscounts = new Decimal(0);
    let sumTaxable = new Decimal(0);
    let sumCgst = new Decimal(0);
    let sumSgst = new Decimal(0);
    let sumIgst = new Decimal(0);
    let sumCess = new Decimal(0);

    const calculatedItems: CalculatedLineItem[] = input.items.map((item) => {
      const qty = new Decimal(item.quantity || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
      const unitPrice = new Decimal(item.unitPrice || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
      const gross = qty.mul(unitPrice).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

      const discount = new Decimal(item.discountAmount || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
      const taxable = Decimal.max(0, gross.minus(discount)).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

      const gstRate = new Decimal(item.gstRate || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
      const cessRate = new Decimal(item.cessRate || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

      let cgst = new Decimal(0);
      let sgst = new Decimal(0);
      let igst = new Decimal(0);
      let cess = new Decimal(0);

      if (enableGst && !taxable.isZero()) {
        if (isInterState) {
          igst = taxable.mul(gstRate).div(100).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
        } else {
          const halfRate = gstRate.div(2);
          cgst = taxable.mul(halfRate).div(100).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
          sgst = taxable.mul(halfRate).div(100).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
        }

        if (!cessRate.isZero()) {
          cess = taxable.mul(cessRate).div(100).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
        }
      }

      const lineTotal = taxable.plus(cgst).plus(sgst).plus(igst).plus(cess).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

      sumGross = sumGross.plus(gross);
      sumLineDiscounts = sumLineDiscounts.plus(discount);
      sumTaxable = sumTaxable.plus(taxable);
      sumCgst = sumCgst.plus(cgst);
      sumSgst = sumSgst.plus(sgst);
      sumIgst = sumIgst.plus(igst);
      sumCess = sumCess.plus(cess);

      return {
        productId: item.productId,
        variantId: item.variantId,
        description: item.description,
        hsnCode: item.hsnCode,
        quantity: qty,
        unitPrice,
        grossAmount: gross,
        discountAmount: discount,
        taxableAmount: taxable,
        gstRate,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        cessAmount: cess,
        totalAmount: lineTotal,
      };
    });

    const invoiceDiscount = new Decimal(input.invoiceDiscountAmount || 0).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
    const totalDiscount = sumLineDiscounts.plus(invoiceDiscount).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
    const finalTaxable = Decimal.max(0, sumTaxable.minus(invoiceDiscount)).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

    const totalTax = sumCgst.plus(sumSgst).plus(sumIgst).plus(sumCess).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
    const rawTotal = finalTaxable.plus(totalTax).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

    // Standard commercial round-off to nearest rupee (half-up)
    const roundedInt = Math.round(rawTotal.toNumber());
    const roundedTotal = new Decimal(roundedInt).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);
    const roundOff = roundedTotal.minus(rawTotal).toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

    return {
      isInterState,
      placeOfSupply: input.placeOfSupply,
      items: calculatedItems,
      subtotal: sumGross.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      discountAmount: totalDiscount,
      taxableAmount: finalTaxable,
      cgstAmount: sumCgst.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      sgstAmount: sumSgst.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      igstAmount: sumIgst.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      cessAmount: sumCess.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      taxAmount: totalTax,
      roundOff,
      totalAmount: roundedTotal,
    };
  }
}
