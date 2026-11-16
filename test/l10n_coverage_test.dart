import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';

/// كل نص عربي في الكود المترجَم يجب أن يكون له مقابل في assets/l10n/{en,tr}.json،
/// ويجب ألا يُعرض عبر Text العادي (لا يترجم).
///
/// المجلدات تُضاف هنا كلما اكتملت ترجمتها. لطباعة الناقص بصيغة جاهزة للترجمة:
///   flutter test test/l10n_coverage_test.dart --dart-define=L10N_DUMP=lib/screens/home
const translatedPaths = <String>[
  'lib/screens/home',
  'lib/screens/search',
  'lib/screens/category',
  'lib/screens/product',
  'lib/screens/cart',
  'lib/screens/checkout',
  'lib/screens/orders',
  'lib/screens/returns',
  'lib/screens/profile',
  'lib/screens/favorites',
  'lib/screens/followed_stores',
  'lib/screens/coupons',
  'lib/screens/loyalty',
  'lib/screens/notifications',
  'lib/screens/auth',
  'lib/screens/store',
  'lib/screens/chat',
  'lib/screens/messages',
  'lib/screens/seller',
  'lib/screens/employee',
  'lib/screens/admin',
  'lib/screens/splash_screen.dart',
  'lib/widgets',
  'lib/main.dart',
  'lib/utils',
  'lib/models',
  'lib/services',
  'lib/providers',
];

/// نصوص عربية ليست واجهة (أنماط بحث، بيانات اختبار...) — مسار:نص.
const ignored = <String>{
  // تحليل نص الكوبون القادم من السيرفر
  'lib/models/store_coupon.dart: حتى',
  // نص يُكتب في حقل العنوان ليكمله المستخدم (بيانات لا واجهة)
  'lib/screens/profile/my_addresses_screen.dart:\${suggestion.details}، ',
  // أول حرف بديل للصورة الرمزية
  'lib/screens/home/home_tab_widgets.dart:؟',
  'lib/screens/home/home_tab_widgets.dart:ق',
  // مفتاح خريطة أيقونات الأقسام
  'lib/screens/home/home_tab.dart:إلكترون',
};

final _arabic = RegExp(r'[؀-ۿ]');

/// نص حرفي من Dart بعد فك الهروب ودمج النصوص المتجاورة ('أ' 'ب').
class ArabicLiteral {
  ArabicLiteral(this.file, this.line, this.value, this.plainText);
  final String file;
  final int line;
  final String value;

  /// يُعرض عبر Text( مباشرة.
  final bool plainText;
}

List<ArabicLiteral> extractArabicLiterals(String path, String src) {
  final out = <ArabicLiteral>[];
  var i = 0;
  int lineAt(int pos) => '\n'.allMatches(src.substring(0, pos)).length + 1;

  // يقرأ نصاً حرفياً واحداً ابتداءً من i ويعيد (القيمة، النهاية) أو null.
  (String, int)? readLiteral(int start) {
    var j = start;
    var raw = false;
    if (src[j] == 'r') {
      raw = true;
      j++;
    }
    if (j >= src.length || (src[j] != "'" && src[j] != '"')) return null;
    final q = src[j];
    final triple = src.startsWith(q * 3, j);
    final close = triple ? q * 3 : q;
    j += close.length;
    final buf = StringBuffer();
    while (j < src.length && !src.startsWith(close, j)) {
      final c = src[j];
      // ${...} قد يحوي نصوصاً بعلامات تنصيص: ننسخه كما هو في الكود (هو جزء المفتاح)
      if (!raw && c == r'$' && j + 1 < src.length && src[j + 1] == '{') {
        var depth = 0;
        var k = j + 1;
        String? inStr;
        while (k < src.length) {
          final ch = src[k];
          if (inStr != null) {
            if (ch == r'\') {
              k += 2;
              continue;
            }
            if (ch == inStr) inStr = null;
          } else if (ch == "'" || ch == '"') {
            inStr = ch;
          } else if (ch == '{') {
            depth++;
          } else if (ch == '}') {
            depth--;
            if (depth == 0) break;
          }
          k++;
        }
        buf.write(src.substring(j, k + 1));
        j = k + 1;
        continue;
      }
      if (!raw && c == r'\') {
        final n = src[j + 1];
        switch (n) {
          case 'n':
            buf.write('\n');
          case 't':
            buf.write('\t');
          case 'u':
            if (src[j + 2] == '{') {
              final end = src.indexOf('}', j);
              buf.writeCharCode(int.parse(src.substring(j + 3, end), radix: 16));
              j = end - 1;
            } else {
              buf.writeCharCode(int.parse(src.substring(j + 2, j + 6), radix: 16));
              j += 4;
            }
          default:
            buf.write(n);
        }
        j += 2;
        continue;
      }
      if (!triple && c == '\n') return null;
      buf.write(c);
      j++;
    }
    return (buf.toString(), j + close.length);
  }

  while (i < src.length) {
    // تعليقات
    if (src.startsWith('//', i)) {
      i = src.indexOf('\n', i);
      if (i < 0) break;
      continue;
    }
    if (src.startsWith('/*', i)) {
      i = src.indexOf('*/', i) + 2;
      continue;
    }
    final c = src[i];
    final isQuote = c == "'" || c == '"' || (c == 'r' && i + 1 < src.length && (src[i + 1] == "'" || src[i + 1] == '"') && (i == 0 || !RegExp(r'\w').hasMatch(src[i - 1])));
    if (!isQuote) {
      i++;
      continue;
    }
    final start = i;
    final first = readLiteral(i);
    if (first == null) {
      i++;
      continue;
    }
    var (value, end) = first;
    // دمج النصوص المتجاورة
    while (true) {
      var k = end;
      while (k < src.length && ' \t\r\n'.contains(src[k])) {
        k++;
      }
      if (k < src.length && (src[k] == "'" || src[k] == '"')) {
        final next = readLiteral(k);
        if (next == null) break;
        value += next.$1;
        end = next.$2;
      } else {
        break;
      }
    }
    if (_arabic.hasMatch(value)) {
      final before = src.substring(start < 120 ? 0 : start - 120, start);
      final plain = RegExp(r'(?<![A-Za-z_])Text\(\s*$').hasMatch(before);
      // سجلات المطوّر لا تظهر للمستخدم
      if (RegExp(r'(debugPrint|print|log)\(\s*$').hasMatch(before)) {
        i = end;
        continue;
      }
      out.add(ArabicLiteral(path, lineAt(start), value, plain));
    }
    i = end;
  }
  return out;
}

Map<String, String> _load(String lang) => Map<String, String>.from(
    jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map);

Iterable<File> _dartFiles(String path) {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.file) return [File(path)];
  if (type != FileSystemEntityType.directory) return const [];
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

/// نصوص ليست واجهة: أنماط RegExp ونطاقات حروف.
bool _isNotUi(String v) => v.startsWith('^') || RegExp(r'^\[.*\]$').hasMatch(v);

/// يستبدل كل متغير بقيمة تجريبية لاتينية، كما سيصل النص فعلاً إلى AppText.
String _sample(String key) {
  final parts = L10nCatalog.placeholders(key);
  final b = StringBuffer();
  var last = 0;
  for (final (start, end, _) in parts) {
    b
      ..write(key.substring(last, start))
      ..write('7');
    last = end;
  }
  b.write(key.substring(last));
  return b.toString();
}

void main() {
  const dump = String.fromEnvironment('L10N_DUMP');
  final arabic = RegExp(r'[؀-ۿ]');

  test('translated screens leave no Arabic in English or Turkish', () {
    final en = _load('en');
    final tr = _load('tr');
    // التركية تُفحص وحدها (بلا الرجوع للإنكليزية) كي لا تُخفي ترجمة ناقصة
    final enL10n = AppLocalizations(const Locale('en'), L10nCatalog({'en': en}));
    final trL10n = AppLocalizations(const Locale('tr'), L10nCatalog({'tr': tr}));
    final problems = <String>[];
    final missing = <String>{};
    final paths = dump.isNotEmpty ? dump.split(',') : translatedPaths;
    for (final path in paths) {
      for (final file in _dartFiles(path)) {
        final rel = file.path.replaceAll(r'\', '/');
        for (final lit in extractArabicLiterals(rel, file.readAsStringSync())) {
          if (_isNotUi(lit.value) || ignored.contains('$rel:${lit.value}')) continue;
          if (lit.plainText) {
            problems.add('$rel:${lit.line} uses Text() — use AppText(): ${lit.value}');
          }
          final sample = _sample(lit.value);
          if (!arabic.hasMatch(sample)) continue; // كله متغيرات: تُفحص النصوص الداخلية وحدها
          if (arabic.hasMatch(enL10n.translate(sample)) || arabic.hasMatch(trL10n.translate(sample))) {
            missing.add(lit.value);
            problems.add('$rel:${lit.line} missing translation: ${lit.value}');
          }
        }
      }
    }
    if (dump.isNotEmpty) {
      final out = File('build/l10n_missing.json')..createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent('  ')
          .convert({for (final k in missing.toList()..sort()) k: ['', '']}));
      for (final p in problems.where((p) => p.contains('uses Text'))) {
        // ignore: avoid_print
        print(p);
      }
      // ignore: avoid_print
      print('missing=${missing.length} plain=${problems.where((p) => p.contains('uses Text')).length} -> build/l10n_missing.json');
      return;
    }
    expect(problems, isEmpty, reason: problems.take(40).join('\n'));
  });

  test('translations keep every placeholder of their key', () {
    final en = _load('en');
    final tr = _load('tr');
    for (final key in {...en.keys, ...tr.keys}) {
      final expected = L10nCatalog.placeholders(key).map((p) => p.$3).toSet();
      for (final (lang, map) in [('en', en), ('tr', tr)]) {
        final v = map[key];
        if (v == null || v.isEmpty) continue;
        for (final name in expected) {
          expect(v.contains('@{$name}'), isTrue, reason: '$lang lacks @{$name} for: $key → $v');
        }
        final rest = expected.fold(v, (String acc, name) => acc.replaceAll('@{$name}', ''));
        expect(rest.contains(r'${'), isFalse, reason: '$lang uses \${} instead of @{}: $v');
      }
    }
  });
}
