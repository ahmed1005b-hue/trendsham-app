import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../theme/theme_switcher.dart';

/// زرّا اللغة والمظهر للشاشات التي يصلها الزائر قبل تسجيل الدخول
/// (الدخول وإنشاء الحساب)، حيث لا توجد صفحة «حسابي» لتغييرهما منها.
class PreferenceButtons extends StatelessWidget {
  const PreferenceButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [LanguageMenuButton(), ThemeToggleButton()],
    );
  }
}

/// قائمة اللغات. كل لغة تُكتب باسمها الأصلي ليجدها من لا يقرأ اللغة الحالية.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  static const _names = {'ar': 'العربية', 'en': 'English', 'tr': 'Türkçe'};

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final current = settings.locale.languageCode;
    return PopupMenuButton<String>(
      tooltip: context.tr('اللغة'),
      icon: const Icon(Icons.translate_rounded),
      initialValue: current,
      onSelected: (code) => settings.setLocale(Locale(code)),
      itemBuilder: (_) => [
        for (final locale in AppLocalizations.supportedLocales)
          CheckedPopupMenuItem<String>(
            value: locale.languageCode,
            checked: locale.languageCode == current,
            // اسم اللغة لا يُترجم
            child: Text(_names[locale.languageCode] ?? locale.languageCode),
          ),
      ],
    );
  }
}
