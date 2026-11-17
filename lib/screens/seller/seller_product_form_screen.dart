import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/category_translations.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/vendor.dart';
import '../../services/product_service.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../models/product_options.dart';
import '../../widgets/app_state_message.dart';
import '../../utils/image_picker_helper.dart';
import 'product_options_controller.dart';
import 'product_options_editor.dart';

class SellerProductFormScreen extends StatefulWidget {
  final Product? product;
  final SellerService? sellerService;
  final ProductService? productService;

  const SellerProductFormScreen({
    super.key,
    this.product,
    this.sellerService,
    this.productService,
  });

  bool get isEditing => product != null;

  @override
  State<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final SellerService _sellerService =
      widget.sellerService ?? SellerService();
  late final ProductService _productService =
      widget.productService ?? ProductService();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _skuController;
  late final TextEditingController _priceController;
  late final TextEditingController _compareAtPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _weightController;

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _describing = false;

  /// مسودة وصف من الاسم والقسم والألوان والمقاسات — البائع يراجعها قبل الحفظ
  Future<void> _writeDescription() async {
    final name = _nameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: AppText('اكتب اسم المنتج أولاً.')));
      return;
    }
    if (_descriptionController.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const AppText('سيُستبدل الوصف الحالي بالمسودة. متابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('متابعة')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _describing = true);
    try {
      final text = await _sellerService.describeProduct(
        name: name,
        categoryId: _selectedCategoryId,
        colors: _describeColors(),
        sizes: _describeSizes(),
      );
      if (!mounted) return;
      setState(() => _descriptionController.text = text);
      messenger.showSnackBar(const SnackBar(
          content: AppText('تمت كتابة المسودة ✅ راجعها وعدّلها قبل الحفظ.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted) setState(() => _describing = false);
    }
  }

  String _status = 'draft';
  final List<XFile> _newImages = [];
  List<ProductImage> _existingImages = [];
  ProductOptionsController? _options;

  /// لون كل صورة جديدة (مفتاح اللون في المحرر) بنفس ترتيب [_newImages].
  final List<String?> _newImageColors = [];

  /// اختيار لون الصور المحفوظة: المفتاح موجود فقط إذا اختير لون أو "بدون لون".
  final Map<int, String?> _existingImageColors = {};

  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _error;

  List<String> _describeColors() {
    final options = _options;
    if (options == null || !options.enabled) return const [];
    final names = <String>[];
    for (final c in options.colors) {
      final name = c.name.trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    return names;
  }

  List<String> _describeSizes() {
    final options = _options;
    if (options == null || !options.enabled) return const [];
    return options.sizes;
  }

  /// يحافظ على حقل مخزون المنتج مساوياً لمجموع الخيارات ما دام المحرر مفعلاً.
  void _syncStockWithOptions() {
    final options = _options;
    if (options == null || !options.enabled) return;
    final total = options.totalStock.toString();
    if (_stockController.text != total) {
      _stockController.text = total;
    }
  }

  void _onOptionsChanged() {
    _syncStockWithOptions();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _options?.removeListener(_onOptionsChanged);
    _options?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _priceController = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _compareAtPriceController = TextEditingController(
        text: p?.compareAtPrice != null
            ? p!.compareAtPrice!.toStringAsFixed(2)
            : '');
    _stockController = TextEditingController(
        text: p != null ? p.stockQuantity.toString() : '0');
    _lowStockController = TextEditingController(text: '5');
    _weightController = TextEditingController();
    _selectedCategoryId = p?.category?.id;
    _existingImages = p?.images ?? [];

    _loadInitialData();
  }

  /// هل للمنتج المحفوظ (المجلوب كاملاً) خيارات ألوان/مقاسات.
  bool _hadVariants = false;

  Future<void> _loadInitialData() async {
    try {
      final rawCategories = await _sellerService.categories();
      final seen = <int>{};
      final categories = <Category>[];
      for (final c in rawCategories) {
        if (seen.add(c.id)) categories.add(c);
      }

      if (widget.isEditing) {
        final full = await _productService.show(widget.product!.slug);
        _skuController.text = full.sku ?? '';
        if (full.weightGrams != null) {
          _weightController.text = (full.weightGrams! / 1000)
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'\.?0+$'), '');
        }
        _existingImages = full.images;
        _selectedCategoryId = full.category?.id;
        _hadVariants = full.variants.isNotEmpty;
        ProductOptionsController? controller;
        try {
          final catalog = await _sellerService.productOptions();
          controller = ProductOptionsController(catalog);
          controller.load(full.variants);
        } catch (_) {
          controller?.dispose();
          controller = null;
        }
        if (!mounted) {
          controller?.dispose();
          return;
        }
        if (controller != null) {
          _attachOptions(controller);
          for (final img in _existingImages) {
            final key = _mappedColorKey(img);
            if (key != null) _existingImageColors[img.id] = key;
          }
        }
      } else {
        ProductOptionsController? controller;
        try {
          controller =
              ProductOptionsController(await _sellerService.productOptions());
        } catch (_) {
          controller = null;
        }
        if (!mounted) {
          controller?.dispose();
          return;
        }
        if (controller != null) _attachOptions(controller);
      }
      if (!mounted) return;

      final resolvedCategoryId = _selectedCategoryId != null &&
              categories.any((c) => c.id == _selectedCategoryId)
          ? _selectedCategoryId
          : null;

      setState(() {
        _categories = categories;
        _selectedCategoryId = resolvedCategoryId;
        _isLoadingInitial = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoadingInitial = false;
      });
    } catch (_) {
      setState(() {
        _error = 'تعذّر تحميل البيانات.';
        _isLoadingInitial = false;
      });
    }
  }

  void _attachOptions(ProductOptionsController controller) {
    _options = controller;
    controller.addListener(_onOptionsChanged);
    _syncStockWithOptions();
  }

  /// مفتاح اللون الحالي في المحرر الذي يطابق لون صورة محفوظة، أو null.
  String? _mappedColorKey(ProductImage img) {
    final options = _options;
    if (options == null) return null;
    final raw = (img.color ?? '').trim();
    if (raw.isEmpty) return null;
    for (final c in options.colors) {
      if (c.key == raw || c.originalKey == raw) return c.key;
    }
    if (isHexColor(raw)) {
      final hex = canonicalHex(raw);
      for (final c in options.colors) {
        if (c.key == hex || c.hex == hex) return c.key;
      }
    }
    return null;
  }

  OptionColor? _colorByKey(String? key) {
    final options = _options;
    if (key == null || options == null) return null;
    for (final c in options.colors) {
      if (c.key == key) return c;
    }
    return null;
  }

  String _colorLabel(OptionColor color) =>
      _options?.catalog.byHex(color.key)?.label ?? color.name;

  Future<void> _pickImages() async {
    final result = await ImagePickerHelper.pickMultiple();

    if (result.accepted.isNotEmpty) {
      setState(() {
        _newImages.addAll(result.accepted);
        _newImageColors.addAll(result.accepted.map((_) => null));
      });
    }

    if (result.errors.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('بعض الصور مرفوضة'),
          content: AppText(result.errors.join('\n\n')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('حسناً'))
          ],
        ),
      );
    }
  }

  Future<void> _deleteExistingImage(ProductImage image) async {
    try {
      await _sellerService.deleteProductImage(widget.product!.id, image.id);
      setState(() => _existingImages.removeWhere((i) => i.id == image.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _setPrimaryImage(ProductImage image) async {
    try {
      await _sellerService.setPrimaryImage(widget.product!.id, image.id);
      setState(() => _existingImages = [
            for (final i in _existingImages)
              ProductImage(
                id: i.id,
                url: i.url,
                isPrimary: i.id == image.id,
                color: i.color,
                colorName: i.colorName,
                colorHex: i.colorHex,
              ),
          ]);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _error = 'اختر قسم المنتج.');
      return;
    }

    final options = _options;
    final optionsError = options?.validate();
    if (optionsError != null) {
      setState(() => _error = optionsError);
      return;
    }
    if (widget.isEditing &&
        options != null &&
        !options.enabled &&
        _hadVariants) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content:
              const AppText('سيتم حذف كل الألوان والمقاسات عند الحفظ. متابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('متابعة')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (widget.isEditing &&
        options != null &&
        options.enabled &&
        options.droppedOnLoad > 0) {
      final message = context
          .tr('سيتم حذف :count من الخيارات القديمة التي لا تناسب الجدول عند الحفظ. متابعة؟')
          .replaceAll(':count', '${options.droppedOnLoad}');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('متابعة')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    _syncStockWithOptions();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final fields = <String, String>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'sku': _skuController.text.trim().isEmpty
          ? 'SKU-${DateTime.now().millisecondsSinceEpoch}'
          : _skuController.text.trim(),
      'category_id': _selectedCategoryId.toString(),
      'price': _priceController.text.trim(),
      if (_compareAtPriceController.text.trim().isNotEmpty)
        'compare_at_price': _compareAtPriceController.text.trim(),
      'stock_quantity': _stockController.text.trim(),
      'low_stock_threshold': _lowStockController.text.trim().isEmpty
          ? '5'
          : _lowStockController.text.trim(),
      'weight_kg': _weightController.text.trim(),
      'status': _status,
    };
    if (options != null) {
      fields.addAll(SellerService.variantFields(options.toVariantMaps(),
          replace: widget.isEditing));
      _addImageColorFields(fields);
    }

    try {
      if (widget.isEditing) {
        await _sellerService.updateProduct(widget.product!.id,
            fields: fields, images: _newImages);
      } else {
        await _sellerService.createProduct(fields: fields, images: _newImages);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: AppText(widget.isEditing
                ? 'تم تحديث المنتج.'
                : 'تم إنشاء المنتج، بانتظار موافقة الإدارة.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر حفظ المنتج.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addImageColorFields(Map<String, String> fields) {
    if (!(_options?.enabled ?? false)) {
      for (final img in _existingImages) {
        if ((img.color ?? '').trim().isEmpty &&
            _existingImageColors[img.id] == null) {
          continue;
        }
        fields['existing_image_color[${img.id}]'] = '';
        fields['existing_image_color_name[${img.id}]'] = '';
      }
      return;
    }
    for (var i = 0; i < _newImages.length; i++) {
      final color =
          _colorByKey(i < _newImageColors.length ? _newImageColors[i] : null);
      if (color == null) continue;
      fields['image_color[$i]'] = color.hex ?? color.key;
      fields['image_color_name[$i]'] = color.name;
    }
    for (final img in _existingImages) {
      if (!_existingImageColors.containsKey(img.id)) continue;
      final color = _colorByKey(_existingImageColors[img.id]);
      fields['existing_image_color[${img.id}]'] =
          color == null ? '' : (color.hex ?? color.key);
      fields['existing_image_color_name[${img.id}]'] = color?.name ?? '';
    }
  }

  Future<void> _pickImageColor({int? existingId, int? newIndex}) async {
    final options = _options;
    if (options == null) return;
    final current = existingId != null
        ? _existingImageColors[existingId]
        : _newImageColors[newIndex!];
    final colors = options.enabled ? options.colors : <OptionColor>[];
    final picked = await showModalBottomSheet<List<String?>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: AppText('لون الصورة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const AppText('بدون لون'),
              selected: current == null,
              onTap: () => Navigator.pop(ctx, <String?>[null]),
            ),
            for (final c in colors)
              ListTile(
                leading: _colorDot(c.hex),
                title: Text(_colorLabel(c)),
                selected: current == c.key,
                onTap: () => Navigator.pop(ctx, <String?>[c.key]),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (existingId != null) {
        _existingImageColors[existingId] = picked.first;
      } else {
        _newImageColors[newIndex!] = picked.first;
      }
    });
  }

  Widget _colorDot(String? hex) {
    final color = isHexColor(hex)
        ? Color(int.parse('FF${canonicalHex(hex!).substring(1)}', radix: 16))
        : null;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: context.cardBorder),
      ),
      child:
          color == null ? const Icon(Icons.palette_outlined, size: 14) : null,
    );
  }

  Widget? _imageColorChip({int? existingId, int? newIndex}) {
    final options = _options;
    if (options == null) return null;
    final key = existingId != null
        ? _existingImageColors[existingId]
        : _newImageColors[newIndex!];
    final color = options.enabled ? _colorByKey(key) : null;
    return InkWell(
      onTap: () => _pickImageColor(existingId: existingId, newIndex: newIndex),
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.cardBorder),
            ),
            child: Tooltip(
              message: context.tr('لون الصورة'),
              child: _colorDot(color?.hex),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: AppText(widget.isEditing ? 'تعديل منتج' : 'منتج جديد')),
      body: _isLoadingInitial
          ? const LoadingIndicator()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: context.softTint(Colors.red),
                              borderRadius: BorderRadius.circular(8)),
                          child: AppText(_error!,
                              style: const TextStyle(color: AppColors.danger)),
                        ),
                      const AppText('صور المنتج',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._existingImages.map((img) => _imageThumb(
                                child: Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  child: CachedNetworkImage(
                                      imageUrl: img.url,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center),
                                ),
                                colorChip: _imageColorChip(existingId: img.id),
                                onDelete: () => _deleteExistingImage(img),
                                isPrimary: img.isPrimary,
                                onSetPrimary: () => _setPrimaryImage(img),
                              )),
                          ..._newImages
                              .asMap()
                              .entries
                              .map((entry) => _imageThumb(
                                    child: Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      child: Image.file(File(entry.value.path),
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center),
                                    ),
                                    colorChip:
                                        _imageColorChip(newIndex: entry.key),
                                    onDelete: () => setState(() {
                                      _newImages.removeAt(entry.key);
                                      _newImageColors.removeAt(entry.key);
                                    }),
                                  )),
                          InkWell(
                            onTap: _pickImages,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.cardBorder),
                              ),
                              child: const Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.emerald),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId != null &&
                                _categories
                                    .any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null,
                        hint: AppText(AppLocalizations.of(context)
                            .translate('اختر القسم')),
                        decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)
                                .translate('القسم')),
                        items: _categories
                            .map((c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: AppText(
                                    CategoryTranslations.translate(c.name))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)
                                .translate('اسم المنتج')),
                        validator: (v) => (v == null || v.isEmpty)
                            ? AppLocalizations.of(context).translate('مطلوب')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)
                                .translate('الوصف (اختياري)')),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: _describing ? null : _writeDescription,
                          icon: _describing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: const AppText('اكتب الوصف تلقائياً'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _skuController,
                        decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).translate(
                                'رمز المنتج SKU (اختياري - يُنشأ تلقائياً لو تُرك فارغاً)')),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                      .translate('السعر (ل.س)')),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? AppLocalizations.of(context)
                                      .translate('مطلوب')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _compareAtPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                      .translate('السعر قبل الخصم')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              readOnly: _options?.enabled ?? false,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                      .translate('الكمية بالمخزون'),
                                  helperText: (_options?.enabled ?? false)
                                      ? context.tr(
                                          'يُحسب تلقائياً من الألوان والمقاسات')
                                      : null,
                                  helperMaxLines: 2),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? AppLocalizations.of(context)
                                      .translate('مطلوب')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lowStockController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                      .translate('حد تنبيه المخزون')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('product-weight'),
                        controller: _weightController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('وزن القطعة مع التغليف'),
                          suffixText: context.tr('كغ'),
                          helperText: context.tr(
                              'لحساب أجرة الشحن: الطرد من 10 كغ فأكثر أجرته أعلى.'),
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          final n = double.tryParse(t);
                          return n == null || n < 0 || n > 1000
                              ? context.tr('اكتب وزناً صحيحاً بالكيلو.')
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _status,
                        decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)
                                .translate('الحالة')),
                        items: const [
                          DropdownMenuItem(
                              value: 'draft', child: AppText('مسودة')),
                          DropdownMenuItem(
                              value: 'active',
                              child: AppText('نشط (يحتاج موافقة الإدارة)')),
                          DropdownMenuItem(
                              value: 'inactive', child: AppText('غير نشط')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'draft'),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            border: Border.all(color: context.cardBorder),
                            borderRadius: BorderRadius.circular(12)),
                        child: _options == null
                            ? AppText('تعذّر تحميل الألوان والمقاسات.',
                                style: TextStyle(color: context.mutedText))
                            : ProductOptionsEditor(controller: _options!),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : AppText(widget.isEditing
                                ? 'حفظ التعديلات'
                                : 'إنشاء المنتج'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _imageThumb(
      {required Widget child,
      required VoidCallback onDelete,
      bool isPrimary = false,
      Widget? colorChip,
      VoidCallback? onSetPrimary}) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        if (isPrimary)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(4)),
              child: const AppText('رئيسية',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          )
        else if (onSetPrimary != null)
          Positioned(
            top: 2,
            right: 2,
            child: Tooltip(
              message: 'تعيين كصورة رئيسية',
              child: InkWell(
                onTap: onSetPrimary,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.star_border,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        if (colorChip != null)
          PositionedDirectional(bottom: 2, end: 2, child: colorChip),
        PositionedDirectional(
          bottom: 2,
          start: 2,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: AppColors.danger, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
