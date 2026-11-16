import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../utils/role_router.dart';
import '../../widgets/preference_buttons.dart';
import '../legal/legal_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool returnAfterAuth;

  const RegisterScreen({super.key, this.returnAfterAuth = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _accountType = 'customer';
  XFile? _identityDocument;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _otpStep = false;
  bool _agreedToTerms = false;
  bool _employeePendingApproval = false;
  String? _errorMessage;

  @override
  void dispose() {
    _deleteLocalIdentityDocument();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _storeNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickIdentityDocument() async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (selected == null) return;

      final extension = selected.name.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        await File(selected.path).delete();
        setState(() => _errorMessage = 'اختر صورة بصيغة JPG أو PNG أو WEBP.');
        return;
      }
      if (await File(selected.path).length() > 5 * 1024 * 1024) {
        await File(selected.path).delete();
        setState(() => _errorMessage = 'يجب ألا يتجاوز حجم الصورة 5 ميغابايت.');
        return;
      }

      final previous = _identityDocument;
      setState(() {
        _identityDocument = selected;
        _errorMessage = null;
      });
      if (previous != null && previous.path != selected.path) {
        await File(previous.path).delete();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'تعذّر اختيار الصورة. حاول مرة أخرى.');
      }
    }
  }

  Future<void> _deleteLocalIdentityDocument() async {
    final document = _identityDocument;
    _identityDocument = null;
    if (document == null) return;
    try {
      final file = File(document.path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountType == 'seller' && _identityDocument == null) {
      setState(
          () => _errorMessage = 'أرفق صورة الهوية قبل متابعة تسجيل البائع.');
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMessage =
          'يجب الموافقة على الشروط والأحكام وسياسة الخصوصية للمتابعة.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().startRegistration(
            accountType: _accountType,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _passwordConfirmController.text,
            storeName: _accountType == 'seller'
                ? _storeNameController.text.trim()
                : null,
          );

      setState(() => _otpStep = true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'أدخل رمز التحقق كاملاً (6 أرقام).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final approved = await context.read<AuthProvider>().verifyRegistration(
            _phoneController.text.trim(),
            _codeController.text.trim(),
            identityDocument:
                _accountType == 'seller' ? _identityDocument : null,
          );

      if (!mounted) return;
      if (!approved) {
        setState(() => _employeePendingApproval = true);
        return;
      }
      await _deleteLocalIdentityDocument();
      if (!mounted) return;
      final role = context.read<AuthProvider>().user!.role;
      routeAfterAuthentication(
        context,
        role,
        returnToCaller: widget.returnAfterAuth,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('إنشاء حساب'),
        actions: const [PreferenceButtons(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _employeePendingApproval
              ? _buildEmployeePendingApproval()
              : _otpStep
                  ? _buildOtpStep()
                  : _buildDetailsStep(),
        ),
      ),
    );
  }

  Widget _buildEmployeePendingApproval() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top, size: 56, color: AppColors.gold),
        const SizedBox(height: 16),
        const AppText(
          'تم تأكيد رقم هاتفك. طلب الانضمام كموظف بانتظار موافقة المدير.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppText('إنهاء'),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) _errorBanner(),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _accountType,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context).translate('نوع الحساب')),
            items: const [
              DropdownMenuItem(
                value: 'customer',
                child: AppText(
                  'عميل - أريد التسوّق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'seller',
                child: AppText(
                  'بائع - أريد فتح متجر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'employee',
                child: AppText(
                  'موظف - أطلب الانضمام لفريق العمل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) {
              final accountType = v ?? 'customer';
              setState(() => _accountType = accountType);
              if (accountType != 'seller') {
                unawaited(_deleteLocalIdentityDocument());
              }
            },
          ),
          if (_accountType == 'employee') ...[
            const SizedBox(height: 8),
            const AppText(
              'سيُفعّل حساب الموظف بعد مراجعة المدير والموافقة على الطلب.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('الاسم')),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppLocalizations.of(context).translate('مطلوب')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('اللقب')),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppLocalizations.of(context).translate('مطلوب')
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate('رقم الهاتف'),
                hintText: AppLocalizations.of(context).translate('09xxxxxxxx')),
            validator: (v) => (v == null || v.isEmpty)
                ? AppLocalizations.of(context).translate('مطلوب')
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)
                    .translate('البريد الإلكتروني')),
            validator: (v) => (v == null || v.isEmpty)
                ? AppLocalizations.of(context).translate('مطلوب')
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)
                    .translate('العنوان (اختياري)')),
          ),
          const SizedBox(height: 16),
          if (_accountType == 'seller') ...[
            TextFormField(
              controller: _storeNameController,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).translate('اسم المتجر')),
              validator: (v) {
                if (_accountType == 'seller' && (v == null || v.isEmpty)) {
                  return AppLocalizations.of(context)
                      .translate('مطلوب لحساب البائع');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildIdentityDocumentPicker(),
          ],
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate('كلمة السر'),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              helperText: context.tr('8 أحرف على الأقل، حرف كبير وصغير، رقم، ورمز'),
              helperMaxLines: 2,
            ),
            validator: (v) => (v == null || v.length < 8)
                ? AppLocalizations.of(context).translate('كلمة السر ضعيفة')
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordConfirmController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context).translate('تأكيد كلمة السر')),
            validator: (v) => (v != _passwordController.text)
                ? AppLocalizations.of(context).translate('غير مطابق')
                : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                activeColor: AppColors.emerald,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const AppText('أوافق على ',
                          style: TextStyle(fontSize: 13)),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LegalScreen(type: LegalPageType.terms)),
                        ),
                        child: const AppText(
                          'الشروط والأحكام',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const AppText(' و', style: TextStyle(fontSize: 13)),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const LegalScreen(
                                  type: LegalPageType.privacy)),
                        ),
                        child: const AppText(
                          'سياسة الخصوصية',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitDetails,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const AppText('متابعة'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) _errorBanner(),
        AppText(
          'أرسلنا رمز تحقق مكوّن من 6 أرقام إلى ${_phoneController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        if (_accountType == 'seller') ...[
          _buildIdentityDocumentPicker(),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyCode,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const AppText('تأكيد وإنشاء الحساب'),
        ),
        TextButton(
          onPressed: () => setState(() => _otpStep = false),
          child: const AppText('تعديل البيانات'),
        ),
      ],
    );
  }

  Widget _buildIdentityDocumentPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppText(
          'صورة هوية وطنية أو صفحة بيانات جواز السفر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const AppText(
          'JPG أو PNG أو WEBP، بحد أقصى 5 ميغابايت. تُرفع مباشرة عند تأكيد رمز OTP، وتُتاح للإدارة فقط.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_identityDocument != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_identityDocument!.path),
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const AppText(
                'تعذّرت معاينة الصورة المختارة.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pickIdentityDocument,
          icon: Icon(_identityDocument == null
              ? Icons.add_photo_alternate_outlined
              : Icons.refresh),
          label: AppText(_identityDocument == null
              ? 'اختيار صورة الهوية'
              : 'اختيار صورة مختلفة'),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: AppText(_errorMessage!,
          style: const TextStyle(color: AppColors.danger)),
    );
  }
}
