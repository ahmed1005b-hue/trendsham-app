import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/employee/employee_home_tab.dart';
import 'package:trendsham/services/admin_operations_service.dart';
import 'package:trendsham/services/admin_review_service.dart';
import 'package:trendsham/services/admin_service.dart';
import 'package:trendsham/services/admin_tools_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';

class _FakeAdminService extends AdminService {
  @override
  Future<Map<String, int>> employeeDashboard() async => {
        'new_orders': 4,
        'late_orders': 1,
        'pending_products': 2,
        'seller_support': 0,
        'customer_chats': 3,
        'returns': 5,
      };
}

Future<void> _pump(WidgetTester tester, {double width = 412}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ThemeController(prefs: prefs),
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: EmployeeHomeTab(service: _FakeAdminService()),
    ),
  ));
  await tester.pumpAndSettle();
}

String _count(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey('employee-count-$key'))).data!;

void main() {
  testWidgets('employee home shows today\'s work counts like the website',
      (tester) async {
    await _pump(tester);

    expect(find.text('طلبات جديدة'), findsOneWidget);
    expect(_count(tester, 'new_orders'), '4');
    expect(_count(tester, 'customer_chats'), '3');
    expect(_count(tester, 'seller_support'), '0');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('employee-tile-returns')), 200);
    expect(_count(tester, 'returns'), '5');
  });

  testWidgets('employee home fits a small phone', (tester) async {
    await _pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });

  test('employee services call the employee API, admin ones stay on /admin',
      () {
    expect(AdminOperationsService.employee().supportBase, '/employee');
    expect(AdminOperationsService().supportBase, '/admin');
    expect(AdminToolsService.employee().chatsBase, '/employee');
    expect(AdminToolsService().chatsBase, '/admin');
    expect(AdminReviewService.employee().returnsBase, '/employee');
    expect(AdminReviewService().returnsBase, '/admin');
  });
}
