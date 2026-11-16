import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/seller_profile.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/app_state_message.dart';

class SellerStoreProfileScreen extends StatefulWidget {
  final SellerProfileModel store;

  const SellerStoreProfileScreen({super.key, required this.store});

  @override
  State<SellerStoreProfileScreen> createState() =>
      _SellerStoreProfileScreenState();
}

class _SellerStoreProfileScreenState extends State<SellerStoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerService = SellerService();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _instagramController;
  late final TextEditingController _hoursController;
  late final TextEditingController _hoursScheduleController;
  late final TextEditingController _shippingController;
  late final TextEditingController _returnsController;
  XFile? _newLogo;
  XFile? _newBanner;
  bool _isSaving = false;
  String? _error;

  String _translate(String value) =>
      AppLocalizations.of(context).translate(value);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.storeName);
    _descriptionController =
        TextEditingController(text: widget.store.storeDescription ?? '');
    _phoneController =
        TextEditingController(text: widget.store.storeContactPhone ?? '');
    _whatsappController =
        TextEditingController(text: widget.store.storeWhatsapp ?? '');
    _instagramController =
        TextEditingController(text: widget.store.storeInstagram ?? '');
    _hoursController =
        TextEditingController(text: widget.store.businessHours ?? '');
    _hoursScheduleController = TextEditingController(
      text: widget.store.businessHoursSchedule == null
          ? ''
          : const JsonEncoder.withIndent('  ')
              .convert(widget.store.businessHoursSchedule),
    );
    _shippingController =
        TextEditingController(text: widget.store.shippingPolicy ?? '');
    _returnsController =
        TextEditingController(text: widget.store.returnPolicy ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _hoursController.dispose();
    _hoursScheduleController.dispose();
    _shippingController.dispose();
    _returnsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final result = await ImagePickerHelper.pickSingle();
    if (!mounted) return;

    if (result.accepted.isNotEmpty) {
      setState(() {
        if (isLogo) {
          _newLogo = result.accepted.first;
        } else {
          _newBanner = result.accepted.first;
        }
      });
    } else if (result.errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(result.errors.first)),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _sellerService.updateStore(
        fields: {
          'store_name': _nameController.text.trim(),
          'store_description': _descriptionController.text.trim(),
          'store_contact_phone': _phoneController.text.trim(),
          'store_whatsapp': _whatsappController.text.trim(),
          'store_instagram': _instagramController.text.trim(),
          'business_hours': _hoursController.text.trim(),
          'business_hours_schedule': _hoursScheduleController.text.trim(),
          'shipping_policy': _shippingController.text.trim(),
          'return_policy': _returnsController.text.trim(),
        },
        files: {
          if (_newLogo != null) 'store_logo': _newLogo!,
          if (_newBanner != null) 'store_banner': _newBanner!,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر حفظ بيانات المتجر: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _imagePreview({
    required XFile? selectedImage,
    required String? existingImage,
    required BoxFit fit,
    required Widget fallback,
  }) {
    if (selectedImage != null) {
      return Image.file(File(selectedImage.path), fit: fit);
    }
    if (existingImage != null && existingImage.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: existingImage,
        fit: fit,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return fallback;
  }

  Widget _imagePicker({
    required String title,
    required String help,
    required XFile? selectedImage,
    required String? existingImage,
    required bool isLogo,
  }) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        isLogo ? Icons.storefront_outlined : Icons.panorama_outlined,
        size: isLogo ? 38 : 44,
        color: AppColors.muted,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        AppText(help,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(isLogo ? 48 : 10),
              child: SizedBox(
                width: isLogo ? 96 : 150,
                height: isLogo ? 96 : 82,
                child: _imagePreview(
                  selectedImage: selectedImage,
                  existingImage: existingImage,
                  fit: BoxFit.cover,
                  fallback: placeholder,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : () => _pickImage(isLogo: isLogo),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: AppText(
                  selectedImage != null || (existingImage?.isNotEmpty ?? false)
                      ? 'اختيار صورة أخرى'
                      : 'اختيار صورة',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('واجهة متجري')),
      body: _isSaving
          ? const LoadingIndicator()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppText(
                    'عرّف المشترين بمتجرك وأضف صوراً تساعدهم على التعرّف على علامتك.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _imagePicker(
                    title: 'صورة المتجر',
                    help:
                        'تظهر بجانب اسم المتجر. المقاس الموصى به 512×512 بكسل. JPG أو PNG أو WEBP حتى 4 ميغابايت.',
                    selectedImage: _newLogo,
                    existingImage: widget.store.storeLogo,
                    isLogo: true,
                  ),
                  const SizedBox(height: 22),
                  _imagePicker(
                    title: 'الصورة العريضة',
                    help:
                        'تظهر في أعلى صفحة متجرك. المقاس الموصى به 1200×400 بكسل. JPG أو PNG أو WEBP حتى 4 ميغابايت.',
                    selectedImage: _newBanner,
                    existingImage: widget.store.storeBanner,
                    isLogo: false,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const ValueKey('store-name-input'),
                    controller: _nameController,
                    maxLength: 255,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _translate('اسم المتجر'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? _translate('اسم المتجر مطلوب.')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _translate('نبذة عن المتجر'),
                      hintText: _translate(
                          'اكتب ما يميز متجرك والمنتجات التي تقدمها.'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: context.tr('هاتف التواصل'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      return phone.isEmpty ||
                              RegExp(r'^\+?[0-9\s().-]{6,32}$').hasMatch(phone)
                          ? null
                          : context.tr('أدخل رقم هاتف صالحاً.');
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _whatsappController,
                    maxLength: 2048,
                    decoration: InputDecoration(
                      labelText: context.tr('واتساب (رابط أو رقم)'),
                      hintText: context.tr('https://wa.me/... أو رقم دولي'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _validLinkOrPhone(value)
                        ? null
                        : context.tr('أدخل رقم واتساب أو رابطاً يبدأ بـ http أو https.'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _instagramController,
                    maxLength: 2048,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.tr('رابط إنستغرام'),
                      hintText: 'https://instagram.com/...',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _validHttpUrl(value)
                        ? null
                        : context.tr('يجب أن يبدأ الرابط بـ http:// أو https://.'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hoursController,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.tr('أوقات العمل'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hoursScheduleController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.tr('جدول الدوام (JSON اختياري)'),
                      hintText:
                          '{"timezone":"Asia/Damascus","days":{"mon":[{"open":"09:00","close":"13:00"},{"open":"16:00","close":"20:00"}],"tue":[]}}',
                      helperText: context.tr('أيام mon إلى sun. استخدم [] ليوم مغلق. الأوقات 24 ساعة، ويمكن إضافة أكثر من فترة في اليوم. الوصف النصي وحده لا يحدد حالة الفتح.'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shippingController,
                    maxLength: 4000,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('سياسة الشحن'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _returnsController,
                    maxLength: 4000,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('سياسة الإرجاع والاستبدال'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _livePreview(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppStateMessage(
                        message: _error!, icon: Icons.error_outline),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const AppText('حفظ بيانات المتجر'),
                  ),
                ],
              ),
            ),
    );
  }

  bool _validLinkOrPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty ||
        RegExp(r'^\+?[0-9\s().-]{6,32}$').hasMatch(trimmed)) {
      return true;
    }
    return _validHttpUrl(trimmed);
  }

  bool _validHttpUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Widget _livePreview() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _nameController,
        _descriptionController,
        _phoneController,
        _whatsappController,
        _instagramController,
        _hoursController,
        _shippingController,
        _returnsController,
      ]),
      builder: (context, _) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: _imagePreview(
                selectedImage: _newBanner,
                existingImage: widget.store.storeBanner,
                fit: BoxFit.cover,
                fallback: Container(
                  color: AppColors.goldSoft,
                  alignment: Alignment.center,
                  child: const Icon(Icons.storefront_outlined,
                      color: AppColors.primary, size: 36),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: _imagePreview(
                            selectedImage: _newLogo,
                            existingImage: widget.store.storeLogo,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: AppColors.goldSoft,
                              child: const Icon(Icons.storefront,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          _nameController.text.trim().isEmpty
                              ? 'اسم المتجر'
                              : _nameController.text.trim(),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_descriptionController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AppText(_descriptionController.text.trim()),
                  ],
                  const SizedBox(height: 8),
                  AppText([
                    _phoneController.text.trim(),
                    _whatsappController.text.trim(),
                    _instagramController.text.trim(),
                  ].where((value) => value.isNotEmpty).join(' · ')),
                  if (_hoursController.text.trim().isNotEmpty)
                    AppText('أوقات العمل: ${_hoursController.text.trim()}'),
                  if (_shippingController.text.trim().isNotEmpty)
                    AppText('الشحن: ${_shippingController.text.trim()}'),
                  if (_returnsController.text.trim().isNotEmpty)
                    AppText(
                        'الإرجاع والاستبدال: ${_returnsController.text.trim()}'),
                  const SizedBox(height: 6),
                  const AppText('معاينة مباشرة — لن تُحفظ قبل الضغط على حفظ.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
