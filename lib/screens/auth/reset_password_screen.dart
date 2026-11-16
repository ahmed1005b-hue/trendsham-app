import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/api_exception.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  const ResetPasswordScreen({super.key, required this.identifier});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().resetPassword(
        identifier: widget.identifier,
        code: _codeController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: AppText(AppLocalizations.of(context)
                .translate('تم تغيير كلمة المرور'))),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
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
      appBar: AppBar(title: AppText(l10n.translate('تغيير كلمة المرور'))),
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
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.translate('رمز التحقق'),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.translate('مطلوب')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.translate('كلمة المرور الجديدة'),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.translate('مطلوب')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.translate('تأكيد كلمة المرور'),
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : AppText(l10n.translate('تغيير كلمة المرور')),
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
