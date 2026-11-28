import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/seller/seller_support_screen.dart';
import 'package:trendsham/services/support_service.dart';

class _FakeSupportService extends SupportService {
  SupportAccessState state = const SupportAccessState(active: false);
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> getConversations() async => [];

  @override
  Future<SupportAccessState> getAccess() async => state;

  @override
  Future<SupportAccessState> grantAccess() async {
    calls.add('grant');
    return state = SupportAccessState(
      active: true,
      grantedAt: DateTime(2026, 11, 28, 9),
      actions: [
        SupportAccessAction(
            description: 'عدّل المنتج «قميص»',
            at: DateTime(2026, 11, 28, 9, 5)),
      ],
    );
  }

  @override
  Future<SupportAccessState> revokeAccess() async {
    calls.add('revoke');
    return state =
        SupportAccessState(active: false, actions: List.of(state.actions));
  }
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, SupportService service) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SellerSupportScreen(service: service),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'seller allows the support team in after confirming, then ends it',
      (tester) async {
    final service = _FakeSupportService();
    await pumpScreen(tester, service);

    expect(find.byKey(const ValueKey('support-access-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-access-grant')));
    await tester.pumpAndSettle();
    expect(find.text('السماح لفريق الدعم بالدخول'), findsOneWidget);
    await tester.tap(find.text('اسمح'));
    await tester.pumpAndSettle();

    expect(service.calls, ['grant']);
    expect(find.byKey(const ValueKey('support-access-revoke')), findsOneWidget);
    expect(find.text('عدّل المنتج «قميص»'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-access-revoke')));
    await tester.pumpAndSettle();

    expect(service.calls, ['grant', 'revoke']);
    expect(find.byKey(const ValueKey('support-access-grant')), findsOneWidget);
    expect(find.text('عدّل المنتج «قميص»'), findsOneWidget); // السجل يبقى
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the dialog keeps the store closed', (tester) async {
    final service = _FakeSupportService();
    await pumpScreen(tester, service);

    await tester.tap(find.byKey(const ValueKey('support-access-grant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.byKey(const ValueKey('support-access-grant')), findsOneWidget);
  });

  test('access state reads the server answer', () {
    final state = SupportAccessState.fromJson({
      'active': true,
      'granted_at': '2026-11-28T09:00:00.000000Z',
      'actions': [
        {
          'description': 'فتح فريق الدعم لوحة متجرك',
          'at': '2026-11-28T09:01:00Z'
        },
        {'description': ''},
      ],
    });

    expect(state.active, isTrue);
    expect(state.grantedAt, isNotNull);
    expect(state.actions.single.description, 'فتح فريق الدعم لوحة متجرك');
  });
}
