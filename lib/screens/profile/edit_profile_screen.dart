import 'dart:io';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/api_exception.dart';
import '../../utils/image_picker_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _nationalNumberController;
  late final TextEditingController _cityController;
  DateTime? _birthDate;
  String? _gender;
  XFile? _selectedAvatar;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _countryCodeController =
        TextEditingController(text: user?.countryCode ?? '');
    _nationalNumberController =
        TextEditingController(text: user?.nationalNumber ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _gender = user?.gender;
  }

  Future<void> _pickAvatar() async {
    final result = await ImagePickerHelper.pickSingle();
    if (result.accepted.isNotEmpty) {
      setState(() => _selectedAvatar = result.accepted.first);
    } else if (result.errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(result.errors.first)),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updated = await _profileService.update(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        nationalNumber: _nationalNumberController.text.trim(),
        birthDate: _birthDate?.toIso8601String().substring(0, 10),
        city: _cityController.text.trim(),
        gender: _gender,
        avatarImage: _selectedAvatar,
      );

      if (!mounted) return;
      context.read<AuthProvider>().updateUser(updated);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم تحديث بياناتك بنجاح.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر حفظ التعديلات.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const AppText('تعديل البيانات الشخصية')),
      body: SafeArea(
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: AppText(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),

                // profile-avatar
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: ClipOval(
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: _selectedAvatar != null
                                ? Image.file(
                                    File(_selectedAvatar!.path),
                                    fit: BoxFit.cover,
                                  )
                                : (user?.avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: user!.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.goldSoft,
                                          child: const Icon(Icons.person,
                                              size: 50,
                                              color: AppColors.primary),
                                        ),
                                        placeholder: (_, __) => Container(
                                          color: AppColors.goldSoft,
                                          child: const Icon(Icons.person,
                                              size: 50,
                                              color: AppColors.primary),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.goldSoft,
                                        child: const Icon(Icons.person,
                                            size: 50, color: AppColors.primary),
                                      )),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: AppText(
                    'اضغط لتغيير صورة البروفايل',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('الاسم')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.tr('الاسم مطلوب.')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('اللقب')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.tr('اللقب مطلوب.')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('البريد الإلكتروني')),
                  keyboardType: TextInputType.emailAddress,
                  // البريد إلزامي (قرار المتجر)، ويُتحقق من صيغته قبل الإرسال
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return context.tr('البريد الإلكتروني مطلوب.');
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                      return context.tr('صيغة البريد الإلكتروني غير صحيحة.');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('العنوان')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _countryCodeController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr('رمز الدولة'),
                          hintText: '+90',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nationalNumberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr('رقم الهاتف'),
                          hintText: '5xxxxxxxxx',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _birthDate ?? DateTime(DateTime.now().year - 18),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _birthDate = picked);
                  },
                  child: InputDecorator(
                    decoration:
                        InputDecoration(labelText: context.tr('تاريخ الميلاد')),
                    child: AppText(
                      _birthDate == null
                          ? 'اختر التاريخ'
                          : '${_birthDate!.year}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    'الجنس',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                RadioGroup<String>(
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                  child: const Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: AppText('ذكر'),
                          value: 'male',
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: AppText('أنثى'),
                          value: 'female',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(labelText: context.tr('المدينة')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: user?.phone,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context).translate('رقم الهاتف'),
                    helperText: context.tr('رقم موثّق ولا يمكن تعديله من هنا'),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const AppText('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
