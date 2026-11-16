import 'package:flutter/material.dart';
import '../screens/home/main_screen.dart';
import '../screens/seller/seller_main_screen.dart';
import '../screens/admin/admin_main_screen.dart';
import '../screens/employee/employee_main_screen.dart';

Widget roleHomeScreen(String role) {
  switch (role) {
    case 'seller':
      return const SellerMainScreen();
    case 'admin':
      return const AdminMainScreen();
    case 'employee':
      return const EmployeeMainScreen();
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
