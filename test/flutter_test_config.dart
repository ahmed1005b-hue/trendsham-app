import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';

/// يُشغَّل قبل كل ملف اختبار: يحمّل ملفات الترجمة خارج الوقت الوهمي
/// كي تبني الواجهات الإنكليزية والتركية من أول إطار كما في التطبيق.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await L10nCatalog.load();
  await testMain();
}
