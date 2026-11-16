import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../image_picker_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/api_exception.dart';
import '../../services/return_service.dart';
import 'return_detail_screen.dart';

/// الحد الأقصى لصور الطلب (يطابق ReturnService::MAX_PHOTOS في السيرفر).
const int maxReturnPhotos = 5;

/// تسمية سبب الإرجاع (مفاتيح السيرفر الثابتة)، بنفس نص ReturnRequest::REASON_LABELS في السيرفر.
String returnReasonLabel(String key) {
  switch (key) {
    case 'damaged':
      return 'المنتج تالف';
    case 'not_as_described':
      return 'لا يطابق الوصف';
    case 'wrong_size_or_color':
      return 'مقاس أو لون خاطئ';
    case 'changed_mind':
      return 'غيّرت رأيي';
    default:
      return 'سبب آخر';
  }
}

/// نموذج إنشاء طلب إرجاع لسطور طلب واحد. [lines] هي ناتج returnable.
class CreateReturnScreen extends StatefulWidget {
  const CreateReturnScreen({
    super.key,
    required this.orderId,
    required this.lines,
    this.service,
  });

  final int orderId;
  final List<ReturnableLine> lines;

  /// قابل للاستبدال في الاختبارات.
  final ReturnService? service;

  @override
  State<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  late final ReturnService _service = widget.service ?? ReturnService();
  final TextEditingController _description = TextEditingController();
  final Map<int, int> _quantities = {};
  final List<XFile> _photos = [];
  String? _reason;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _setQuantity(ReturnableLine line, int value) {
    setState(() {
      _quantities[line.orderItemId] = value.clamp(0, line.returnableQuantity);
      _error = null;
    });
  }

  Future<void> _pickPhotos() async {
    final result = await ImagePickerHelper.pickMultiple();
    if (!mounted) return;
    setState(() {
      for (final file in result.accepted) {
        if (_photos.length < maxReturnPhotos) _photos.add(file);
      }
    });
    if (result.errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(result.errors.first)));
    }
  }

  Future<void> _submit() async {
    final selected = {
      for (final e in _quantities.entries)
        if (e.value > 0) e.key: e.value
    };
    if (selected.isEmpty) {
      setState(() => _error = 'اختر منتجاً واحداً على الأقل بكمية أكبر من صفر.');
      return;
    }
    if (_reason == null) {
      setState(() => _error = 'اختر سبب الإرجاع.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final created = await _service.create(
        widget.orderId,
        lines: selected,
        reason: _reason!,
        description: _description.text,
        photos: _photos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم إرسال طلب الإرجاع.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReturnDetailScreen(returnId: created.id)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر إرسال طلب الإرجاع.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _lineTile(ReturnableLine line) {
    final qty = _quantities[line.orderItemId] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(line.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (line.variantLabel != null)
                  AppText(line.variantLabel!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                Wrap(spacing: 8, children: [
                  AppText('${line.unitPrice.toStringAsFixed(0)} ل.س',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  AppText('المتاح للإرجاع: ${line.returnableQuantity}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('إنقاص الكمية'),
            onPressed: qty > 0 ? () => _setQuantity(line, qty - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 24,
            child: Text('$qty',
                key: ValueKey('qty-${line.orderItemId}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: context.tr('زيادة الكمية'),
            onPressed: qty < line.returnableQuantity
                ? () => _setQuantity(line, qty + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  /// السطور مجمّعة حسب المتجر بترتيب ظهورها؛ طلب الإرجاع الواحد يخص متجراً واحداً.
  List<List<ReturnableLine>> get _storeGroups {
    final groups = <Object?, List<ReturnableLine>>{};
    for (final line in widget.lines) {
      groups.putIfAbsent(line.vendorId ?? line.storeName, () => []).add(line);
    }
    return groups.values.toList();
  }

  List<Widget> _storeSection(List<ReturnableLine> lines) {
    final storeName = lines.first.storeName;
    return [
      if (storeName != null && storeName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppText('المتجر: $storeName',
              style: const TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600)),
        ),
      ...lines.map(_lineTile),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final storeGroups = _storeGroups;
    return Scaffold(
      appBar: AppBar(title: const AppText('طلب إرجاع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('المنتجات المراد إرجاعها',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (storeGroups.length > 1)
                    const AppText('طلب الإرجاع الواحد يخص متجراً واحداً.',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  for (final group in storeGroups) ..._storeSection(group),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('سبب الإرجاع',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final key in returnReasonKeys)
                    ListTile(
                      key: ValueKey('reason-$key'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _reason == key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _reason == key
                            ? AppColors.brandGreen
                            : AppColors.muted,
                      ),
                      title: AppText(returnReasonLabel(key)),
                      onTap: () => setState(() {
                        _reason = key;
                        _error = null;
                      }),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: context.tr('وصف المشكلة (اختياري)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('الصور (اختياري، حتى $maxReturnPhotos)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final photo in _photos)
                        Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(photo.path),
                                width: 72, height: 72, fit: BoxFit.cover),
                          ),
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: InkWell(
                              onTap: () => setState(() => _photos.remove(photo)),
                              child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close,
                                      size: 12, color: Colors.white)),
                            ),
                          ),
                        ]),
                      if (_photos.length < maxReturnPhotos)
                        InkWell(
                          onTap: _pickPhotos,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.muted),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppText(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const AppText('إرسال طلب الإرجاع'),
          ),
        ],
      ),
    );
  }
}
