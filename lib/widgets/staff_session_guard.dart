import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home/main_screen.dart';

/// يحمي لوحات البائع والمدير والموظف: إن انتهت الجلسة (تسجيل خروج، إغلاق الحساب،
/// انتهاء التوكن) أو تغيّر الدور، لا تبقى اللوحة ظاهرة لحظة واحدة، وينتقل التطبيق
/// فوراً إلى الصفحة الرئيسية مع حذف كل الصفحات المفتوحة خلفها.
class StaffSessionGuard extends StatefulWidget {
  const StaffSessionGuard({super.key, required this.role, required this.child});

  /// الدور الذي تخصه اللوحة: seller أو admin أو employee.
  final String role;
  final Widget child;

  @override
  State<StaffSessionGuard> createState() => _StaffSessionGuardState();
}

class _StaffSessionGuardState extends State<StaffSessionGuard> {
  bool _leaving = false;

  void _leaveToHome() {
    if (_leaving) {
      return;
    }
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || user.role != widget.role) {
      _leaveToHome();
      return const Scaffold(body: SizedBox.shrink());
    }
    return widget.child;
  }
}
