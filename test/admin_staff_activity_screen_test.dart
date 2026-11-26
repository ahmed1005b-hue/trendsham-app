import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_staff_activity_screen.dart';
import 'package:trendsham/services/admin_service.dart';

class _FakeAdminService extends AdminService {
  final List<({int? userId, String? group})> calls = [];

  @override
  Future<StaffActivityPage> staffActivity(
      {int? userId,
      String? group,
      String? from,
      String? to,
      int page = 1}) async {
    calls.add((userId: userId, group: group));
    final all = [
      const StaffActivityEntry(
          id: 1,
          actorName: 'سامر',
          isAdmin: false,
          action: 'order.status',
          description: 'غيّر حالة الطلب TS-1 من «قيد المراجعة» إلى «قيد التجهيز»'),
      const StaffActivityEntry(
          id: 2,
          actorName: 'سامر',
          isAdmin: false,
          action: 'product.approve',
          description: 'وافق على المنتج «قميص»'),
    ];
    return StaffActivityPage(
      group == null
          ? all
          : all.where((e) => e.action.startsWith('$group.')).toList(),
      const [(id: 7, name: 'سامر', isAdmin: false)],
      const [('order', 'الطلبات'), ('product', 'المنتجات')],
      1,
      1,
    );
  }
}

void main() {
  testWidgets('admin sees who did what and filters by type of work',
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
      home: AdminStaffActivityScreen(service: service),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('غيّر حالة الطلب TS-1'), findsOneWidget);
    expect(find.text('وافق على المنتج «قميص»'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'المنتجات'));
    await tester.pumpAndSettle();

    expect(service.calls.last.group, 'product');
    expect(find.textContaining('غيّر حالة الطلب TS-1'), findsNothing);
    expect(find.text('وافق على المنتج «قميص»'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
