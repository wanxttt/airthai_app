class Gstr1B2bInvoice {
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerName;
  final String? customerGstin;
  final String placeOfSupply;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final double totalInvoiceAmount;

  Gstr1B2bInvoice({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    this.customerGstin,
    required this.placeOfSupply,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
    required this.totalInvoiceAmount,
  });

  factory Gstr1B2bInvoice.fromJson(Map<String, dynamic> json) {
    return Gstr1B2bInvoice(
      invoiceNumber: json['invoiceNumber'] ?? '',
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate']) ?? DateTime.now()
          : DateTime.now(),
      customerName: json['customerName'] ?? '',
      customerGstin: json['customerGstin'],
      placeOfSupply: json['placeOfSupply'] ?? '',
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      totalInvoiceAmount: (json['totalInvoiceAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HsnSummaryItem {
  final String hsnCode;
  final String description;
  final double quantity;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;

  HsnSummaryItem({
    required this.hsnCode,
    required this.description,
    required this.quantity,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
  });

  factory HsnSummaryItem.fromJson(Map<String, dynamic> json) {
    return HsnSummaryItem(
      hsnCode: json['hsnCode'] ?? '',
      description: json['description'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      taxableValue: (json['taxableValue'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Gstr1Model {
  final String returnPeriod;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTaxLiability;
  final int table4B2bCount;
  final double table4B2bTaxable;
  final double table4B2bTax;
  final List<Gstr1B2bInvoice> b2bInvoices;
  final int table7B2cCount;
  final double table7B2cTaxable;
  final double table7B2cTax;
  final List<HsnSummaryItem> hsnSummary;
  final String disclaimer;

  Gstr1Model({
    required this.returnPeriod,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTaxLiability,
    required this.table4B2bCount,
    required this.table4B2bTaxable,
    required this.table4B2bTax,
    required this.b2bInvoices,
    required this.table7B2cCount,
    required this.table7B2cTaxable,
    required this.table7B2cTax,
    required this.hsnSummary,
    required this.disclaimer,
  });

  factory Gstr1Model.fromJson(Map<String, dynamic> json, String disclaimer) {
    final t4 = json['table4B2B'] ?? {};
    final t7 = json['table7B2C'] ?? {};
    final rawInvoices = t4['invoices'] as List? ?? [];
    final rawHsn = json['table12HsnSummary'] as List? ?? [];

    return Gstr1Model(
      returnPeriod: json['returnPeriod'] ?? '',
      totalTaxableValue: (json['totalTaxableValue'] as num?)?.toDouble() ?? 0.0,
      totalCgst: (json['totalCgst'] as num?)?.toDouble() ?? 0.0,
      totalSgst: (json['totalSgst'] as num?)?.toDouble() ?? 0.0,
      totalIgst: (json['totalIgst'] as num?)?.toDouble() ?? 0.0,
      totalCess: (json['totalCess'] as num?)?.toDouble() ?? 0.0,
      totalTaxLiability: (json['totalTaxLiability'] as num?)?.toDouble() ?? 0.0,
      table4B2bCount: (t4['count'] as num?)?.toInt() ?? 0,
      table4B2bTaxable: (t4['taxableValue'] as num?)?.toDouble() ?? 0.0,
      table4B2bTax: (t4['taxAmount'] as num?)?.toDouble() ?? 0.0,
      b2bInvoices: rawInvoices.map((e) => Gstr1B2bInvoice.fromJson(e)).toList(),
      table7B2cCount: (t7['count'] as num?)?.toInt() ?? 0,
      table7B2cTaxable: (t7['taxableValue'] as num?)?.toDouble() ?? 0.0,
      table7B2cTax: (t7['taxAmount'] as num?)?.toDouble() ?? 0.0,
      hsnSummary: rawHsn.map((e) => HsnSummaryItem.fromJson(e)).toList(),
      disclaimer: disclaimer,
    );
  }
}

class Gstr3bModel {
  final String returnPeriod;
  final double outwardTaxable;
  final double outwardIgst;
  final double outwardCgst;
  final double outwardSgst;
  final double totalOutwardTax;
  final double itcTaxable;
  final double itcIgst;
  final double itcCgst;
  final double itcSgst;
  final double totalItcAvailable;
  final double netPayableIgst;
  final double netPayableCgst;
  final double netPayableSgst;
  final double totalNetPayable;
  final String disclaimer;

  Gstr3bModel({
    required this.returnPeriod,
    required this.outwardTaxable,
    required this.outwardIgst,
    required this.outwardCgst,
    required this.outwardSgst,
    required this.totalOutwardTax,
    required this.itcTaxable,
    required this.itcIgst,
    required this.itcCgst,
    required this.itcSgst,
    required this.totalItcAvailable,
    required this.netPayableIgst,
    required this.netPayableCgst,
    required this.netPayableSgst,
    required this.totalNetPayable,
    required this.disclaimer,
  });

  factory Gstr3bModel.fromJson(Map<String, dynamic> json, String disclaimer) {
    final t31 = json['table31OutwardSupplies'] ?? {};
    final t4 = json['table4EligibleItc'] ?? {};
    final net = json['netTaxPayable'] ?? {};

    return Gstr3bModel(
      returnPeriod: json['returnPeriod'] ?? '',
      outwardTaxable: (t31['taxableValue'] as num?)?.toDouble() ?? 0.0,
      outwardIgst: (t31['igstAmount'] as num?)?.toDouble() ?? 0.0,
      outwardCgst: (t31['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      outwardSgst: (t31['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      totalOutwardTax: (t31['totalOutwardTax'] as num?)?.toDouble() ?? 0.0,
      itcTaxable: (t4['taxableValue'] as num?)?.toDouble() ?? 0.0,
      itcIgst: (t4['igstAmount'] as num?)?.toDouble() ?? 0.0,
      itcCgst: (t4['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      itcSgst: (t4['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      totalItcAvailable: (t4['totalItcAvailable'] as num?)?.toDouble() ?? 0.0,
      netPayableIgst: (net['igst'] as num?)?.toDouble() ?? 0.0,
      netPayableCgst: (net['cgst'] as num?)?.toDouble() ?? 0.0,
      netPayableSgst: (net['sgst'] as num?)?.toDouble() ?? 0.0,
      totalNetPayable: (net['totalPayable'] as num?)?.toDouble() ?? 0.0,
      disclaimer: disclaimer,
    );
  }
}
