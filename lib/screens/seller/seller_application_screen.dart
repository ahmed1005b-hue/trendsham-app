import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/seller_application_service.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/app_state_message.dart';
import '../../l10n/app_localizations.dart';

class SellerApplicationScreen extends StatefulWidget {
  const SellerApplicationScreen({super.key});

  @override
  State<SellerApplicationScreen> createState() =>
      _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  final SellerApplicationService _service = SellerApplicationService();
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commercialRegisterController = TextEditingController();
  final _identityNumberController = TextEditingController();

  String? _identityType;
  XFile? _identityDocument;
  XFile? _identityDocumentBack;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _storeNameController.text = (profile['store_name'] ?? '').toString();
        _descriptionController.text =
            (profile['store_description'] ?? '').toString();
        _commercialRegisterController.text =
            (profile['commercial_register'] ?? '').toString();
        _identityType = profile['identity_type']?.toString();
      });
    } catch (_) {
      // No existing profile is fine for first-time application.
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    _commercialRegisterController.dispose();
    _identityNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({required bool back}) async {
    final result = await ImagePickerHelper.pickIdentityDocument();
    if (!mounted) return;
    if (result.accepted.isNotEmpty) {
      setState(() {
        if (back) {
          _identityDocumentBack = result.accepted.first;
        } else {
          _identityDocument = result.accepted.first;
        }
      });
    } else if (result.errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(result.errors.first)));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_identityDocument == null) {
      setState(() => _error = 'يرجى رفع وثيقة الهوية (صورة أو PDF).');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _service.submitApplication(
        storeName: _storeNameController.text.trim(),
        storeDescription: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        commercialRegister: _commercialRegisterController.text.trim().isEmpty
            ? null
            : _commercialRegisterController.text.trim(),
        identityType: _identityType,
        identityNumber: _identityNumberController.text.trim().isEmpty
            ? null
            : _identityNumberController.text.trim(),
        identityDocument: _identityDocument!,
        identityDocumentBack: _identityDocumentBack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
              'تم إرسال طلب التحقق للمراجعة. سنبلغك عند الاعتماد أو إذا لزم إعادة الإرسال.'),
          backgroundColor: AppColors.emerald,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'تعذّر إرسال الطلب. تحقق من الاتصال وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_profile?['status'] ?? '').toString();
    final statusLabel = (_profile?['status_label'] ?? '').toString();
    final reason = (_profile?['rejection_reason'] ?? '').toString();
    final isIdentityVerified = _profile?['is_identity_verified'] == true ||
        (_profile?['identity_verified_at'] != null &&
            _profile!['identity_verified_at'].toString().isNotEmpty);
    final identityReviewPending = _profile?['identity_review_pending'] == true;
    final canSubmit = !isIdentityVerified;
    final submitLabel = isIdentityVerified
        ? 'تم اعتماد الهوية'
        : status == 'approved' && !isIdentityVerified
            ? (identityReviewPending
                ? 'تحديث الوثيقة أثناء المراجعة'
                : 'إرسال هوية المتجر للتحقق')
            : 'إرسال طلب التحقق';
    return Scaffold(
      appBar: AppBar(title: const AppText('التحقق من هوية البائع')),
      body: _isLoadingProfile || _isSaving
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
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: context.softTint(Colors.red),
                              borderRadius: BorderRadius.circular(8)),
                          child: AppText(_error!,
                              style: const TextStyle(color: AppColors.danger)),
                        ),
                      if (status.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isIdentityVerified
                                ? context.softTint(Colors.green)
                                : status == 'rejected'
                                    ? context.softTint(Colors.red)
                                    : context.softTint(Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                    'حالة التحقق: ${statusLabel.isNotEmpty ? statusLabel : status}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (status == 'rejected' &&
                                    reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  AppText('سبب الرفض: $reason'),
                                  const SizedBox(height: 2),
                                  const AppText(
                                      'ارفع وثيقة أوضح (أو وجهين عند الحاجة) وأعد الإرسال.'),
                                ],
                                if (status == 'pending' && !isIdentityVerified)
                                  const AppText(
                                      'طلبك قيد المراجعة. يمكنك استبدال الوثيقة إذا أخطأت في الملف.'),
                                if (status == 'approved' && !isIdentityVerified)
                                  AppText(identityReviewPending
                                      ? 'متجرك نشط. تم استلام الوثيقة وهي قيد المراجعة؛ يمكنك تحديثها إذا لزم.'
                                      : 'متجرك نشط كبائع قديم، لكن يلزم إرسال وثيقة هوية لإكمال التحقق.'),
                              ]),
                        ),
                      const AppText('بيانات المتجر',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _storeNameController,
                        decoration: InputDecoration(
                            labelText: context.tr('اسم المتجر'),
                            border: const OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? context.tr('اسم المتجر مطلوب.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: context.tr('وصف المتجر (اختياري)'),
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commercialRegisterController,
                        decoration: InputDecoration(
                            labelText: context.tr('السجل التجاري (اختياري)'),
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      const AppText('وثيقة الهوية',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _identityType,
                        decoration: InputDecoration(
                            labelText: context.tr('نوع الوثيقة (اختياري)'),
                            border: const OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem<String?>(
                              value: null, child: AppText('اختر النوع')),
                          DropdownMenuItem(
                              value: 'national_id', child: AppText('هوية وطنية')),
                          DropdownMenuItem(
                              value: 'passport', child: AppText('جواز سفر')),
                          DropdownMenuItem(
                              value: 'residence', child: AppText('إقامة')),
                          DropdownMenuItem(
                              value: 'commercial_register',
                              child: AppText('سجل تجاري')),
                        ],
                        onChanged: (v) => setState(() => _identityType = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _identityNumberController,
                        decoration: InputDecoration(
                          labelText: context.tr('رقم الهوية/السجل (اختياري)'),
                          helperText: context.tr('يُحفظ للمراجعة الإدارية فقط ولا يظهر كاملاً للعملاء.'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _docPicker(
                        title: 'الوجه الأمامي / الوثيقة الأساسية',
                        file: _identityDocument,
                        requiredHint: true,
                        onPick: () => _pickDocument(back: false),
                        onClear: () => setState(() => _identityDocument = null),
                      ),
                      const SizedBox(height: 10),
                      _docPicker(
                        title: 'الوجه الخلفي / صفحة إضافية (اختياري)',
                        file: _identityDocumentBack,
                        requiredHint: false,
                        onPick: () => _pickDocument(back: true),
                        onClear: () =>
                            setState(() => _identityDocumentBack = null),
                      ),
                      const SizedBox(height: 8),
                      const AppText(
                          'حالياً يدعم اختيار الصور الواضحة من المعرض. للتحقق الكامل من PDF، استخدم صفحة الويب إذا لزم.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: AppText(submitLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _docPicker({
    required String title,
    required XFile? file,
    required bool requiredHint,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: context.cardBorder),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (requiredHint)
          const AppText('مطلوب — صورة واضحة أو ملف PDF للوثيقة.',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 8),
        if (file != null)
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: file.name.toLowerCase().endsWith('.pdf')
                  ? Container(
                      width: 88,
                      height: 88,
                      color: context.softTint(AppColors.danger),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf,
                                color: Color(0xFFD32F2F)),
                            SizedBox(height: 2),
                            AppText('PDF',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD32F2F)))
                          ]))
                  : Image.file(File(file.path),
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 88,
                          height: 88,
                          color: Colors.black12,
                          child: const Icon(Icons.description_outlined))),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: AppText(file.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            IconButton(
                tooltip: context.tr('حذف'),
                onPressed: onClear,
                icon:
                    const Icon(Icons.delete_outline, color: AppColors.danger)),
          ])
        else
          OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_outlined),
              label: const AppText('اختيار صورة أو PDF')),
      ]),
    );
  }
}
