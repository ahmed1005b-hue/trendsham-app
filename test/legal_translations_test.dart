import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/legal_content.dart';
import 'package:trendsham/l10n/app_localizations.dart';

/// النص القانوني المترجم (في assets/l10n مع باقي الواجهة) يجب أن يطابق الأصل
/// العربي بنداً بنداً، لا أن يلخّصه: نفس النقاط والفقرات والأرقام
/// (مثل مهلة 3 أيام و30 يوماً)، وبلا أحرف عربية أو علامات استبدال.
void main() {
  late L10nCatalog catalog;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    catalog = await L10nCatalog.load();
  });

  const pages = {
    'terms': LegalContent.terms,
    'privacy': LegalContent.privacy,
    'refundPolicy': LegalContent.refundPolicy,
  };
  final arabic = RegExp(r'[؀-ۿ]');

  int count(String text, String part) => part.allMatches(text).length;
  List<String> numbers(String text) =>
      RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).toList();

  for (final lang in ['en', 'tr']) {
    test('$lang legal pages mirror the Arabic structure', () {
      final l10n = AppLocalizations(Locale(lang), catalog);
      for (final page in pages.entries) {
        for (var i = 0; i < page.value.length; i++) {
          final ar = page.value[i];
          final title = l10n.translate(ar.title);
          final body = l10n.translate(ar.body);
          final where = '$lang/${page.key}[$i]';
          expect(title + body, isNot(matches(arabic)),
              reason: '$where untranslated');
          expect(count(body, '•'), count(ar.body, '•'), reason: '$where bullets');
          expect(count(body, '\n\n'), count(ar.body, '\n\n'),
              reason: '$where paragraphs');
          expect(numbers(title + body), numbers(ar.title + ar.body),
              reason: '$where numbers');
          expect(title.replaceFirst(RegExp(r'\?$'), '') + body,
              isNot(contains('?')),
              reason: '$where replacement characters');
        }
      }
      expect(l10n.translate(LegalContent.disclaimer), isNot(matches(arabic)));
    });
  }
}
