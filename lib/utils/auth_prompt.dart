import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';

enum _AuthAction { login, register }

Future<bool> showAuthRequiredDialog(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;

  final navigator = Navigator.of(context);
  final action = await showDialog<_AuthAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const AppText('تسجيل الدخول مطلوب'),
      content: const AppText('أنشئ حساباً أو سجّل الدخول للمتابعة والشراء.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const AppText('إلغاء'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, _AuthAction.register),
          child: const AppText('إنشاء حساب'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, _AuthAction.login),
          child: const AppText('تسجيل الدخول'),
        ),
      ],
    ),
  );

  if (action == null || !navigator.mounted) return false;
  final authenticated = action == _AuthAction.login
      ? await navigator.push<bool>(
          MaterialPageRoute(
              builder: (_) => const LoginScreen(returnAfterAuth: true)),
        )
      : await navigator.push<bool>(
          MaterialPageRoute(
              builder: (_) => const RegisterScreen(returnAfterAuth: true)),
        );
  return authenticated == true;
}
