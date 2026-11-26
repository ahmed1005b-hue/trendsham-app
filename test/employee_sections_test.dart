import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/screens/admin/admin_employee_sections_tab.dart';
import 'package:trendsham/services/admin_service.dart';

class _FakeAdminService extends AdminService {
  final saved = <int, List<String>>{};

  @override
  Future<EmployeeTeam> employeeTeam() async => const EmployeeTeam(
        [
          (id: 5, name: 'سامر', sections: ['orders', 'support'])
        ],
        [
          ('orders', 'الطلبات'),
          ('products', 'المنتجات'),
          ('support', 'دعم البائعين'),
        ],
      );

  @override
  Future<String> updateEmployeeSections(int id, List<String> sections) async {
    saved[id] = sections;
    return 'تم الحفظ';
  }
}

AppUser _employee(List<String>? sections) => AppUser.fromJson({
      'id': 1,
      'name': 'سامر',
      'role': 'employee',
      if (sections != null) 'employee_sections': sections,
    });

void main() {
  test('an employee without chosen sections works in every section', () {
    expect(_employee(null).canWorkOn('returns'), isTrue);
    final supportOnly = _employee(['support']);
    expect(supportOnly.canWorkOn('support'), isTrue);
    expect(supportOnly.canWorkOn('orders'), isFalse);
  });

  testWidgets('admin changes an employee sections and saves them',
      (tester) async {
    final service = _FakeAdminService();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: AdminEmployeeSectionsTab(service: service)),
    ));
    await tester.pumpAndSettle();

    FilterChip chip(String value) =>
        tester.widget<FilterChip>(find.byKey(ValueKey('section-5-$value')));
    expect(chip('orders').selected, isTrue);
    expect(chip('products').selected, isFalse);

    await tester.tap(find.byKey(const ValueKey('section-5-products')));
    await tester.tap(find.byKey(const ValueKey('section-5-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-sections-5')));
    await tester.pumpAndSettle();

    expect(service.saved[5], unorderedEquals(['support', 'products']));
    expect(tester.takeException(), isNull);
  });
}
