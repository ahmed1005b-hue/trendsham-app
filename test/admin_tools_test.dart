import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_assistant_screen.dart';
import 'package:trendsham/screens/admin/admin_main_screen.dart';
import 'package:trendsham/screens/admin/admin_trash_screen.dart';
import 'package:trendsham/screens/admin/admin_two_factor_screen.dart';
import 'package:trendsham/services/admin_tools_service.dart';
import 'package:trendsham/services/api_exception.dart';

/// لوحة المدير في التطبيق: المحذوفات، والمساعد الذكي، وأمان الحساب (مثل الموقع).
class _Fake extends AdminToolsService {
  final calls = <String>[];
  bool enabled = false;
  bool chatOpen = true;

  @override
  Future<TrashPage> trash({String? type}) async {
    calls.add('trash:${type ?? ''}');
    return const TrashPage('products', [
      ('products', 'المنتجات', 1),
      ('categories', 'الأقسام', 0),
    ], [
      TrashItem(id: 9, title: 'قميص قطن', detail: 'متجر سام'),
    ]);
  }

  @override
  Future<String> restore(String type, int id) async {
    calls.add('restore:$type:$id');
    return 'تم الاسترجاع.';
  }

  @override
  Future<List<ChatSummary>> chats({bool closed = false}) async => const [
        ChatSummary(id: 4, customer: 'زائر', lastMessage: 'طلبي وصل مكسور')
      ];

  ChatThread _thread(List<ChatLine> extra) => ChatThread(
        id: 4,
        status: chatOpen ? 'escalated' : 'closed',
        customer: 'زائر',
        messages: [
          const ChatLine(role: 'user', content: 'طلبي وصل مكسور'),
          ...extra
        ],
      );

  @override
  Future<ChatThread> chat(int id) async => _thread(const []);

  @override
  Future<ChatThread> reply(int id, String message) async {
    calls.add('reply:$message');
    return _thread([
      ChatLine(
          role: 'assistant', content: message, agent: true, agentName: 'أحمد')
    ]);
  }

  @override
  Future<ChatThread> closeChat(int id) async {
    calls.add('close');
    chatOpen = false;
    return _thread(const []);
  }

  @override
  Future<List<AssistantFaq>> faqs() async => const [];

  @override
  Future<AssistantFaq> saveFaq(AssistantFaq faq) async {
    calls.add('faq:${faq.question}:${faq.keywords}');
    return faq;
  }

  @override
  Future<TwoFactorStatus> twoFactor() async => TwoFactorStatus(
        required: true,
        enabled: enabled,
        recoveryRemaining: enabled ? 8 : 0,
        secret: enabled ? null : 'JBSWY3DPEHPK3PXP',
        otpauthUrl: enabled
            ? null
            : 'otpauth://totp/TrendSham:a?secret=JBSWY3DPEHPK3PXP',
      );

  @override
  Future<List<String>> confirmTwoFactor(String code) async {
    if (code != '123456') {
      throw const ApiException('الرمز غير صحيح.', statusCode: 422);
    }
    enabled = true;
    return ['AAAAA-BBBBB', 'CCCCC-DDDDD'];
  }
}

Future<void> _open(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin restores a deleted product', (tester) async {
    final fake = _Fake();
    await _open(tester, AdminTrashScreen(service: fake));

    expect(find.text('قميص قطن'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trash-restore-9')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('restore:products:9'));
  });

  testWidgets('admin replies to and closes an escalated chat', (tester) async {
    final fake = _Fake();
    await _open(tester, AdminAssistantScreen(service: fake));

    await tester.tap(find.byKey(const ValueKey('chat-4')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('chat-reply')), 'سنرسل لك بديلاً');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('reply:سنرسل لك بديلاً'));
    expect(find.text('سنرسل لك بديلاً'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-close')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('close'));
    expect(find.byKey(const ValueKey('chat-reply')), findsNothing);
  });

  testWidgets('admin adds an assistant answer', (tester) async {
    final fake = _Fake();
    await _open(tester, AdminAssistantScreen(service: fake));

    await tester.tap(find.byKey(const ValueKey('assistant-tab-faqs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('faq-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('faq-question')), 'متى يصل طلبي؟');
    await tester.enterText(find.byKey(const ValueKey('faq-keywords')), 'شحن');
    await tester.enterText(
        find.byKey(const ValueKey('faq-answer')), 'خلال 3 أيام.');
    await tester.tap(find.byKey(const ValueKey('faq-save')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('faq:متى يصل طلبي؟:شحن'));
  });

  testWidgets('two-step setup shows recovery codes then opens the dashboard',
      (tester) async {
    final fake = _Fake();
    var opened = false;
    await _open(tester,
        AdminTwoFactorScreen(service: fake, onEnabled: () => opened = true));

    expect(find.byKey(const ValueKey('two-factor-open-app')), findsOneWidget);
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);

    final submit = find.byKey(const ValueKey('two-factor-submit'));
    await tester.enterText(
        find.byKey(const ValueKey('two-factor-code')), '000000');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('الرمز غير صحيح.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('two-factor-code')), '123456');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('two-factor-codes')), findsOneWidget);
    expect(find.text('AAAAA-BBBBB'), findsOneWidget);
    expect(opened, isFalse, reason: 'codes are shown before continuing');

    final done = find.byKey(const ValueKey('two-factor-done'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('the admin dashboard is locked until two-step is set up',
      (tester) async {
    final before = AdminMainScreen.needsTwoFactorSetup;
    addTearDown(() => AdminMainScreen.needsTwoFactorSetup = before);
    AdminMainScreen.needsTwoFactorSetup = () async => true;

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminMainScreen(),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AdminTwoFactorScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // شاشة الإعداد الحقيقية تحاول الاتصال: ننتظر انتهاء مهلة الاتصال
    await tester.pump(const Duration(seconds: 16));
  });
}
