import 'package:flutter/material.dart';

import '../../../../core/services/master_data_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../master_data/models/master_data_models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Products state
  List<ProductModel> _products = [];
  bool _isLoadingProducts = false;
  String? _productsError;
  String _productSearch = '';
  String? _selectedCategoryFilter;
  String _statusFilter = 'ACTIVE';

  // Categories & Units state
  List<CategoryModel> _categories = [];
  List<UnitModel> _units = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMetadata();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final catRes = await MasterDataService.instance.getCategories();
    final unitRes = await MasterDataService.instance.getUnits();
    if (mounted) {
      setState(() {
        if (catRes.success && catRes.data != null) {
          _categories = catRes.data!;
        }
        if (unitRes.success && unitRes.data != null) {
          _units = unitRes.data!;
        }
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    final res = await MasterDataService.instance.getProducts(
      search: _productSearch.isNotEmpty ? _productSearch : null,
      categoryId: _selectedCategoryFilter,
      status: _statusFilter,
    );

    if (!mounted) return;
    setState(() {
      _isLoadingProducts = false;
      if (res.success && res.data != null) {
        _products = res.data!;
      } else {
        _productsError = res.errorMessage ?? 'Failed to load products.';
      }
    });
  }

  // ==========================================
  // PRODUCT DIALOGS & ACTIONS
  // ==========================================

  void _showProductFormDialog({ProductModel? product}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final skuCtrl = TextEditingController(text: product?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final hsnCtrl = TextEditingController(text: product?.hsnCode ?? '');
    final salePriceCtrl = TextEditingController(
        text: product != null ? product.salePrice.toString() : '');
    final purchasePriceCtrl = TextEditingController(
        text: product != null ? product.purchasePrice.toString() : '');
    final mrpCtrl = TextEditingController(
        text: product?.mrp != null ? product!.mrp.toString() : '');
    final openingStockCtrl = TextEditingController(text: '0');
    final minStockCtrl = TextEditingController(
        text: product != null ? product.minStockLevel.toString() : '5');

    String? selectedCatId = product?.categoryId;
    String? selectedUnitId = product?.unitId;
    double gstRate = product?.gstRate ?? 18.0;
    bool trackStock = product?.trackStock ?? true;
    bool isSaving = false;
    String? formError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            product == null ? 'Add New Product' : 'Edit Product',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    // Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        hintText: 'e.g. Wireless Mouse',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Product name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    // SKU & Barcode
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: skuCtrl,
                            decoration: const InputDecoration(
                              labelText: 'SKU Code',
                              hintText: 'e.g. WM-001',
                              prefixIcon: Icon(Icons.qr_code_2_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: barcodeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Barcode',
                              hintText: 'e.g. 8901234567890',
                              prefixIcon: Icon(Icons.barcode_reader),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Category & Unit
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCatId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No Category'),
                              ),
                              ..._categories.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  )),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => selectedCatId = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUnitId,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              prefixIcon: Icon(Icons.straighten_rounded),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No Unit'),
                              ),
                              ..._units.map((u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text('${u.name} (${u.symbol})'),
                                  )),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => selectedUnitId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Pricing
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: salePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Selling Price (₹) *',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Selling price is required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: purchasePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Price (₹)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: mrpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'MRP (₹)',
                              hintText: '0.00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tax & HSN
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<double>(
                            initialValue: gstRate,
                            decoration: const InputDecoration(
                              labelText: 'GST Tax Rate',
                              prefixIcon: Icon(Icons.percent_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                              DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                              DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                              DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                              DropdownMenuItem(value: 28.0, child: Text('28% GST')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => gstRate = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: hsnCtrl,
                            decoration: const InputDecoration(
                              labelText: 'HSN / SAC Code',
                              hintText: 'e.g. 8471',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stock settings
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Track Inventory Stock'),
                      subtitle: const Text('Enable low-stock alerts and movement tracking'),
                      value: trackStock,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setDialogState(() => trackStock = val),
                    ),
                    if (trackStock) ...[
                      Row(
                        children: [
                          if (product == null) ...[
                            Expanded(
                              child: TextFormField(
                                controller: openingStockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Opening Stock Quantity',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.warehouse_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: TextFormField(
                              controller: minStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Low Stock Alert Threshold',
                                hintText: '5',
                                prefixIcon: Icon(Icons.notification_important_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Product Description (Optional)',
                        hintText: 'Additional specifications or remarks',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        formError = null;
                      });

                      final payload = <String, dynamic>{
                        'name': nameCtrl.text.trim(),
                        if (skuCtrl.text.trim().isNotEmpty) 'sku': skuCtrl.text.trim(),
                        if (barcodeCtrl.text.trim().isNotEmpty) 'barcode': barcodeCtrl.text.trim(),
                        if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
                        if (hsnCtrl.text.trim().isNotEmpty) 'hsnCode': hsnCtrl.text.trim(),
                        if (selectedCatId != null) 'categoryId': selectedCatId,
                        if (selectedUnitId != null) 'unitId': selectedUnitId,
                        'salePrice': double.tryParse(salePriceCtrl.text.trim()) ?? 0.0,
                        'purchasePrice': double.tryParse(purchasePriceCtrl.text.trim()) ?? 0.0,
                        if (mrpCtrl.text.trim().isNotEmpty)
                          'mrp': double.tryParse(mrpCtrl.text.trim()),
                        'gstRate': gstRate,
                        'trackStock': trackStock,
                        'minStockLevel': double.tryParse(minStockCtrl.text.trim()) ?? 0.0,
                        if (product == null && openingStockCtrl.text.trim().isNotEmpty)
                          'openingStock': double.tryParse(openingStockCtrl.text.trim()) ?? 0.0,
                      };

                      final res = product == null
                          ? await MasterDataService.instance.createProduct(payload)
                          : await MasterDataService.instance.updateProduct(product.id, payload);

                      if (res.success) {
                        Navigator.pop(ctx);
                        _loadProducts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(
                              product == null
                                  ? 'Product created successfully!'
                                  : 'Product updated successfully!',
                            ),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          formError = res.errorMessage;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(product == null ? 'Create Product' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetailsModal(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: AppTextStyles.title),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.sku != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('SKU: ${product.sku}', style: AppTextStyles.label),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.isArchived
                                  ? Colors.grey.shade200
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: product.isArchived
                                    ? Colors.grey.shade700
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 32),
            // Metrics grid
            Row(
              children: [
                _buildInfoMetric('Selling Price', '₹${product.salePrice.toStringAsFixed(2)}'),
                _buildInfoMetric('Purchase Price', '₹${product.purchasePrice.toStringAsFixed(2)}'),
                _buildInfoMetric(
                  'Current Stock',
                  product.trackStock
                      ? '${product.currentStock.toStringAsFixed(0)} ${product.unitSymbol ?? ''}'
                      : 'Untracked',
                  color: product.isOutOfStock
                      ? Colors.red
                      : (product.isLowStock ? Colors.orange.shade800 : null),
                ),
                _buildInfoMetric('GST Rate', '${product.gstRate.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 20),
            if (product.description != null && product.description!.isNotEmpty) ...[
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(product.description!, style: AppTextStyles.bodySecondary),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showProductFormDialog(product: product);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Product'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await MasterDataService.instance.toggleArchiveProduct(product.id);
                    _loadProducts();
                  },
                  icon: Icon(
                    product.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                    size: 16,
                  ),
                  label: Text(product.isArchived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMetric(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Product Deletion'),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}"?\n\nNote: If this product has been referenced in any invoice or purchase transaction, the system will prevent deletion to preserve your accounting audit trail.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Product'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await MasterDataService.instance.deleteProduct(product.id);
      if (res.success) {
        _loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res.errorMessage ?? 'Cannot delete product.'),
          ),
        );
      }
    }
  }

  // ==========================================
  // CATEGORIES & UNITS MODALS
  // ==========================================

  void _showCategoryDialog({CategoryModel? category}) {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMsg != null)
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'e.g. Hardware, Groceries',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final res = await MasterDataService.instance.createCategory(name);
                if (res.success) {
                  Navigator.pop(ctx);
                  _loadMetadata();
                } else {
                  setDialogState(() => errorMsg = res.errorMessage);
                }
              },
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitDialog({UnitModel? unit}) {
    final nameCtrl = TextEditingController(text: unit?.name ?? '');
    final symbolCtrl = TextEditingController(text: unit?.symbol ?? '');
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(unit == null ? 'Add Unit of Measure' : 'Edit Unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMsg != null)
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit Name *',
                  hintText: 'e.g. Kilogram, Meter, Piece',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolCtrl,
                decoration: const InputDecoration(
                  labelText: 'Symbol *',
                  hintText: 'e.g. kg, m, pcs',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final symbol = symbolCtrl.text.trim();
                if (name.isEmpty || symbol.isEmpty) return;
                final res = await MasterDataService.instance.createUnit(name, symbol);
                if (res.success) {
                  Navigator.pop(ctx);
                  _loadMetadata();
                } else {
                  setDialogState(() => errorMsg = res.errorMessage);
                }
              },
              child: const Text('Save Unit'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BUILD UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tab Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'Products (${_products.length})'),
                      Tab(text: 'Categories (${_categories.length})'),
                      Tab(text: 'Units of Measure (${_units.length})'),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showProductFormDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Product'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildCategoriesTab(),
                _buildUnitsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filters & Search Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products by name, SKU, or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _productSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() => _productSearch = '');
                              _loadProducts();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _productSearch = val);
                    _loadProducts();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Category filter
              DropdownButton<String?>(
                value: _selectedCategoryFilter,
                hint: const Text('All Categories'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (val) {
                  setState(() => _selectedCategoryFilter = val);
                  _loadProducts();
                },
              ),
              const SizedBox(width: 12),
              // Status filter
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                  DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived Only')),
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _statusFilter = val);
                    _loadProducts();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Product List
          Expanded(
            child: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _productsError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                            const SizedBox(height: 12),
                            Text(_productsError!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadProducts, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inventory_2_outlined,
                                    color: AppColors.textMuted, size: 48),
                                const SizedBox(height: 12),
                                const Text('No products found', style: AppTextStyles.title),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add your inventory items to begin tracking stock and sales.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showProductFormDialog(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add First Product'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _products.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = _products[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: p.isArchived
                                          ? Colors.grey.shade100
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      color: p.isArchived
                                          ? Colors.grey
                                          : AppColors.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          p.name,
                                          style: AppTextStyles.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (p.sku != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(p.sku!, style: AppTextStyles.label),
                                        ),
                                      ],
                                      if (p.isArchived) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('ARCHIVED',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.grey)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        if (p.categoryName != null) ...[
                                          Flexible(
                                            child: Text(
                                              p.categoryName!,
                                              style: AppTextStyles.bodySecondary,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Text(' • ',
                                              style: AppTextStyles.bodySecondary),
                                        ],
                                        Text('GST: ${p.gstRate.toStringAsFixed(0)}%',
                                            style: AppTextStyles.bodySecondary),
                                        const Text(' • ',
                                            style: AppTextStyles.bodySecondary),
                                        Flexible(
                                          child: Text(
                                            p.trackStock
                                                ? 'Stock: ${p.currentStock.toStringAsFixed(0)} ${p.unitSymbol ?? ''}'
                                                : 'Stock: Untracked',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: p.isOutOfStock
                                                  ? Colors.red
                                                  : (p.isLowStock
                                                      ? Colors.orange.shade800
                                                      : AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${p.salePrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (p.purchasePrice > 0)
                                            Text(
                                              'Cost: ₹${p.purchasePrice.toStringAsFixed(2)}',
                                              style: AppTextStyles.label,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'view') {
                                            _showProductDetailsModal(p);
                                          } else if (val == 'edit') {
                                            _showProductFormDialog(product: p);
                                          } else if (val == 'archive') {
                                            MasterDataService.instance
                                                .toggleArchiveProduct(p.id)
                                                .then((_) => _loadProducts());
                                          } else if (val == 'delete') {
                                            _handleDeleteProduct(p);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'view',
                                            child: Text('View Details'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit Product'),
                                          ),
                                          PopupMenuItem(
                                            value: 'archive',
                                            child: Text(p.isArchived
                                                ? 'Restore Product'
                                                : 'Archive Product'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showProductDetailsModal(p),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Categories', style: AppTextStyles.title),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('No categories added yet.'))
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final cat = _categories[idx];
                      return ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        leading: const Icon(Icons.category_rounded, color: AppColors.primary),
                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${cat.productCount} product(s) linked'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () async {
                            final res = await MasterDataService.instance.deleteCategory(cat.id);
                            if (res.success) {
                              _loadMetadata();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade700,
                                  content: Text(res.errorMessage ?? 'Cannot delete category.'),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Units of Measurement', style: AppTextStyles.title),
              ElevatedButton.icon(
                onPressed: () => _showUnitDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Unit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _units.isEmpty
                ? const Center(child: Text('No units configured yet.'))
                : ListView.separated(
                    itemCount: _units.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final u = _units[idx];
                      return ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            u.symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Symbol: ${u.symbol} • ${u.productCount} product(s) linked'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () async {
                            final res = await MasterDataService.instance.deleteUnit(u.id);
                            if (res.success) {
                              _loadMetadata();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade700,
                                  content: Text(res.errorMessage ?? 'Cannot delete unit.'),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
