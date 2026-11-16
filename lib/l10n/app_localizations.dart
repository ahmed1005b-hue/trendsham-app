import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// الترجمة: النص العربي في الكود هو المفتاح، والترجمات في assets/l10n/{en,tr}.json
/// (نفس صيغة lang/en.json في الموقع، فملف مراجعة واحد يغطي الاثنين).
///
/// مفاتيح فيها متغيرات تُكتب كما في الكود: 'لديك ${count} طلب' ← 'You have @{count} orders'.
class AppLocalizations {
  AppLocalizations(this.locale, [L10nCatalog? catalog])
      : _catalog = catalog ?? L10nCatalog.empty;

  final Locale locale;
  final L10nCatalog _catalog;

  static const supportedLocales = [Locale('ar'), Locale('en'), Locale('tr')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// 0 = إنكليزي، 1 = تركي، -1 = عربي (لا ترجمة).
  int get _languageIndex => locale.languageCode == 'en'
      ? 0
      : locale.languageCode == 'tr'
          ? 1
          : -1;

  String? _translateDynamic(String value, int languageIndex) {
    final couponDelete = RegExp(
      '^\u062d\u0630\u0641 \u0643\u0648\u0628\u0648\u0646 "(.+)" \u0646\u0647\u0627\u0626\u064a\u0627\u064b\u061f\$',
    ).firstMatch(value);
    if (couponDelete != null) {
      final code = couponDelete.group(1)!;
      return languageIndex == 0
          ? 'Permanently delete coupon "$code"?'
          : '"$code" kuponu kal\u0131c\u0131 olarak silinsin mi?';
    }
    final couponUsage = RegExp(
      '^(.+) \u2022 \u0627\u0633\u062a\u064f\u062e\u062f\u0645 (.+) \u0645\u0631\u0629\$',
    ).firstMatch(value);
    if (couponUsage != null) {
      return languageIndex == 0
          ? '${couponUsage.group(1)} \u2022 Used ${couponUsage.group(2)} times'
          : '${couponUsage.group(1)} \u2022 ${couponUsage.group(2)} kez kullan\u0131ld\u0131';
    }
    final orderLine = RegExp(
      '^\u0637\u0644\u0628 (.*?) \u2022 \u0627\u0644\u0643\u0645\u064a\u0629: (.+)\$',
    ).firstMatch(value);
    if (orderLine != null) {
      return languageIndex == 0
          ? 'Order ${orderLine.group(1)} \u2022 Quantity: ${orderLine.group(2)}'
          : 'Sipari\u015f ${orderLine.group(1)} \u2022 Adet: ${orderLine.group(2)}';
    }
    final pendingBalance = RegExp(
      '^\u0644\u062f\u064a\u0643 (.+) \u0644\\.\u0633 \u0636\u0645\u0646 \u0637\u0644\u0628\u0627\u062a \u0633\u062d\u0628 \u0645\u0639\u0644\u0651\u0642\u0629\$',
    ).firstMatch(value);
    if (pendingBalance != null) {
      return languageIndex == 0
          ? '${pendingBalance.group(1)} SYP in pending withdrawal requests'
          : 'Bekleyen para \u00e7ekme taleplerinde ${pendingBalance.group(1)} SYP';
    }
    final amount =
        RegExp('^([+\\-]?[\\d.,]+) \u0644\\.\u0633\$').firstMatch(value);
    if (amount != null) return '${amount.group(1)} SYP';
    return null;
  }

  static final _arabicLetter = RegExp(r'[؀-ۿ]');

  /// نتائج سابقة: كل Text يمر من هنا، فلا نعيد مطابقة الأنماط لنفس النص.
  final Map<String, String> _memo = {};

  String translate(String value) {
    final languageIndex = _languageIndex;
    if (languageIndex < 0 || value.isEmpty) return value;
    // أسماء لاتينية وأرقام وأسعار: لا شيء يُترجم
    if (!_arabicLetter.hasMatch(value)) return value;
    final cached = _memo[value];
    if (cached != null) return cached;
    // القاموس (نصاً ثم بمتغيرات) قبل القواعد القديمة المكتوبة يدوياً،
    // فهي أعمّ وقد تلتقط جملة لها ترجمة أدق في القاموس.
    final result = _catalog.lookup(value, locale.languageCode) ??
        _catalog.lookupPattern(value, locale.languageCode, translate) ??
        _translateDynamic(value, languageIndex) ??
        value;
    if (_memo.length > 3000) _memo.clear();
    return _memo[value] = result;
  }
}

/// الترجمات المحمّلة من ملفات JSON، مع أنماط المتغيرات مجمّعة مرة واحدة.
class L10nCatalog {
  L10nCatalog(this._byLanguage) {
    final keys = <String>{for (final m in _byLanguage.values) ...m.keys};
    for (final key in keys) {
      if (!key.contains(r'$')) continue;
      final parts = placeholders(key);
      if (parts.isEmpty) continue;
      final pattern = StringBuffer('^');
      var last = 0;
      for (final (start, end, _) in parts) {
        pattern.write(RegExp.escape(key.substring(last, start)));
        pattern.write('(.+?)');
        last = end;
      }
      pattern
        ..write(RegExp.escape(key.substring(last)))
        ..write(r'$');
      _patterns.add((
        key,
        RegExp(pattern.toString(), dotAll: true),
        [for (final p in parts) p.$3],
        key.length - parts.fold(0, (n, p) => n + p.$2 - p.$1),
      ));
    }
    // الأكثر نصاً ثابتاً أولاً: "$n منتج متاح" قبل "$n منتج"
    _patterns.sort((a, b) => b.$4.compareTo(a.$4));
  }

  static final empty = L10nCatalog(const {});

  final Map<String, Map<String, String>> _byLanguage;
  final List<(String, RegExp, List<String>, int)> _patterns = [];

  /// مواضع المتغيرات في مفتاح كما كُتب في الكود: \${expr} (مع أقواس ونصوص متداخلة) أو \$name.
  /// يعيد (البداية، النهاية، الاسم) والاسم هو ما يُكتب في الترجمة كـ @{name}.
  static List<(int, int, String)> placeholders(String key) {
    final out = <(int, int, String)>[];
    var i = 0;
    while (i < key.length - 1) {
      if (key[i] != r'$') {
        i++;
        continue;
      }
      if (key[i + 1] == '{') {
        var depth = 0;
        var k = i + 1;
        String? inStr;
        for (; k < key.length; k++) {
          final ch = key[k];
          if (inStr != null) {
            if (ch == r'\') {
              k++;
            } else if (ch == inStr) {
              inStr = null;
            }
          } else if (ch == "'" || ch == '"') {
            inStr = ch;
          } else if (ch == '{') {
            depth++;
          } else if (ch == '}' && --depth == 0) {
            break;
          }
        }
        if (k >= key.length) break;
        out.add((i, k + 1, key.substring(i + 2, k)));
        i = k + 1;
        continue;
      }
      final m = RegExp(r'[A-Za-z_]\w*').matchAsPrefix(key, i + 1);
      if (m != null) {
        out.add((i, m.end, m.group(0)!));
        i = m.end;
      } else {
        i++;
      }
    }
    return out;
  }

  /// الترجمة التركية الناقصة تعود للإنكليزية بدل العربية.
  String? lookup(String key, String language) {
    final value = _byLanguage[language]?[key];
    if (value != null && value.isNotEmpty) return value;
    if (language != 'en') {
      final en = _byLanguage['en']?[key];
      if (en != null && en.isNotEmpty) return en;
    }
    return null;
  }

  /// [inner] يترجم قيم المتغيرات أيضاً: '\${a.labelText} (معتمد)' ← 'Home (default)'.
  String? lookupPattern(String value, String language, [String Function(String)? inner]) {
    for (final (key, regex, names, _) in _patterns) {
      final match = regex.firstMatch(value);
      if (match == null) continue;
      var translated = lookup(key, language);
      if (translated == null) continue;
      for (var i = 0; i < names.length; i++) {
        final captured = match.group(i + 1)!;
        translated = translated!.replaceAll('@{${names[i]}}', inner?.call(captured) ?? captured);
      }
      return translated;
    }
    return null;
  }

  static Future<L10nCatalog>? _loading;

  /// المحمَّل مسبقاً (عند بدء التطبيق): يُستخدم فوراً دون انتظار.
  static L10nCatalog? loaded;

  /// يُحمَّل مرة واحدة ويُعاد استخدامه.
  static Future<L10nCatalog> load() => _loading ??= () async {
        final data = <String, Map<String, String>>{};
        for (final lang in const ['en', 'tr']) {
          final raw = await rootBundle.loadString('assets/l10n/$lang.json');
          data[lang] = Map<String, String>.from(jsonDecode(raw) as Map);
        }
        return loaded = L10nCatalog(data);
      }();
}

/// ترجمة نص خارج عنصر Text (تلميحات الحقول، عناوين الأزرار، الرسائل).
extension L10nContext on BuildContext {
  String tr(String arabic) => AppLocalizations.of(this).translate(arabic);
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(
        AppLocalizations.of(context).translate(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    // العربية هي لغة الكود: لا ملفات تُحمَّل ولا انتظار
    if (locale.languageCode == 'ar') {
      return SynchronousFuture(AppLocalizations(locale));
    }
    final ready = L10nCatalog.loaded;
    if (ready != null) return SynchronousFuture(AppLocalizations(locale, ready));
    return L10nCatalog.load().then((c) => AppLocalizations(locale, c));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
