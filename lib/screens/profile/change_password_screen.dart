import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/api_exception.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _profileService.updatePassword(
        currentPassword: _currentPasswordController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم تغيير كلمة السر.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تغيير كلمة السر.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('تغيير كلمة السر')),
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
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('كلمة السر الحالية')),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppLocalizations.of(context).translate('مطلوب')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)
                        .translate('كلمة السر الجديدة'),
                    helperText: context.tr('8 أحرف على الأقل، حرف كبير وصغير، رقم، ورمز'),
                    helperMaxLines: 2,
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? AppLocalizations.of(context)
                          .translate('كلمة السر ضعيفة')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('تأكيد كلمة السر الجديدة')),
                  validator: (v) => (v != _passwordController.text)
                      ? AppLocalizations.of(context).translate('غير مطابق')
                      : null,
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
                      : const AppText('تغيير كلمة السر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
