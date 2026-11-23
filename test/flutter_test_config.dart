import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_main_screen.dart';
import 'package:trendsham/services/app_update.dart';
import 'package:trendsham/widgets/social_brand.dart';

/// يُشغَّل قبل كل ملف اختبار: يحمّل ملفات الترجمة خارج الوقت الوهمي
/// كي تبني الواجهات الإنكليزية والتركية من أول إطار كما في التطبيق.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await L10nCatalog.load();
  // قسم «تابعنا» لا يتصل بالإنترنت في الاختبارات
  FollowUsSection.loader = () async => const [];
  // فحص التحديث ورقم الإصدار لا يتصلان بالإنترنت ولا بالمنصة في الاختبارات
  AppUpdateGate.loader = () async => ('1.1.0', null);
  AppVersionLabel.version = () async => '1.1.0';
  // لوحة المدير لا تفحص التحقق بخطوتين عبر الإنترنت في الاختبارات
  AdminMainScreen.needsTwoFactorSetup = () async => false;
  await testMain();
}
