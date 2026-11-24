import 'package:flutter/material.dart';
import '../screens/home/main_screen.dart';
import '../screens/seller/seller_main_screen.dart';
import '../screens/admin/admin_main_screen.dart';
import '../screens/employee/employee_main_screen.dart';
import '../widgets/staff_session_guard.dart';

Widget roleHomeScreen(String role) {
  switch (role) {
    // لوحات العمل محمية: بعد الخروج تعود فوراً للصفحة الرئيسية
    case 'seller':
      return const StaffSessionGuard(role: 'seller', child: SellerMainScreen());
    case 'admin':
      return const StaffSessionGuard(role: 'admin', child: AdminMainScreen());
    case 'employee':
      return const StaffSessionGuard(
          role: 'employee', child: EmployeeMainScreen());
    default:
      if (role == 'customer') return const MainScreen();
      throw ArgumentError.value(role, 'role', 'Unsupported user role');
  }
}

void routeAfterAuthentication(
  BuildContext context,
  String role, {
  required bool returnToCaller,
}) {
  if (returnToCaller && role == 'customer') {
    Navigator.of(context).pop(true);
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => roleHomeScreen(role)),
    (route) => false,
  );
}
