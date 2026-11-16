import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/api_exception.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await AuthService()
          .requestPasswordReset(identifier: _identifierController.text.trim());
      if (!mounted) return;
      setState(() => _successMessage =
          AppLocalizations.of(context).translate('تم إرسال رمز التحقق'));
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
              identifier: _identifierController.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      setState(() =>
          _errorMessage = AppLocalizations.of(context).translate(e.message));
    } catch (_) {
      setState(() => _errorMessage = 'تعذّر الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: AppText(l10n.translate('استعادة كلمة المرور'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _identifierController,
                    decoration: InputDecoration(
                      labelText:
                          l10n.translate('البريد الإلكتروني أو رقم الهاتف'),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.translate('مطلوب')
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(_errorMessage!,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  if (_successMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(_successMessage!,
                          style: const TextStyle(color: Colors.green)),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : AppText(l10n.translate('إرسال رمز التحقق')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
