import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان الهوية — مطابقة لمتغيرات الموقع (--ts-*) في layouts/app.blade.php
/// حتى يبدو الموقع والتطبيق متجراً واحداً.
class AppColors {
  // Brand Identity Colors
  static const Color brandGreen = Color(0xFF0B5F4A); // --ts-emerald
  static const Color brandGreenLight = Color(0xFF1B634B);
  static const Color gold = Color(0xFFC9962C); // --ts-gold
  static const Color goldLight = Color(0xFFF1D9A0); // --ts-gold-light

  /// ذهبي داكن للنصوص فوق الخلفيات الفاتحة (الذهبي العادي لا يُقرأ عليها).
  static const Color goldInk = Color(0xFF7A5410); // --ts-deal-ink

  /// خلفية ذهبية باهتة للشارات والعناصر المحددة.
  static const Color goldSoft = Color(0xFFFBF0D8); // --ts-deal-soft

  // Accent Colors
  static const Color primary = brandGreen;
  static const Color primaryDark = Color(0xFF073D30); // --ts-emerald-dark
  static const Color accent = gold;

  // Specific Use Colors
  /// أحمر نسب الخصم فقط (كما في الموقع).
  static const Color sale = Color(0xFFC23B2A); // --ts-sale
  static const Color danger = Color(0xFFE02020);
  static const Color ratingStar = gold;

  // Neutral Colors
  static const Color darkInk = Color(0xFF1F2A24); // --ts-ink
  static const Color muted = Color(0xFF5F6E66); // --ts-muted
  static const Color border = Color(0xFFE8DFCC); // --ts-border
  static const Color bgLight = Color(0xFFFBF7F0); // --ts-cream

  // Legacy aliases (Consider migrating these out)
  static const Color emerald = brandGreen;
  static const Color emeraldDark = primaryDark;
  static const Color cream = bgLight;
  static const Color ink = darkInk;
}

class AppTheme {
  /// الإنكليزية والتركية بخط النظام (كالموقع: system-ui): Tajawal لا يحوي İ Ş Ğ،
  /// فكان أندرويد يكمّلها بخط آخر داخل الكلمة نفسها. الأحجام والأوزان والألوان كما هي.
  static ThemeData forLanguage(ThemeData theme, String languageCode) {
    if (languageCode == 'ar') return theme;
    // خط النظام كما يعرّفه Flutter: Roboto على أندرويد، وخط آبل على iOS
    final family = Typography.material2021(platform: theme.platform)
        .black
        .bodyMedium
        ?.fontFamily;
    // بيانات عربية داخل واجهة لاتينية (اسم مدينة، منتج، متجر) تبقى بخط العلامة
    final arabicFallback = [GoogleFonts.tajawal().fontFamily!];
    TextStyle plain(TextStyle? s) {
      final style = s ?? const TextStyle();
      return style.copyWith(
        fontFamily: family,
        fontFamilyFallback: arabicFallback,
      );
    }

    final t = theme.textTheme;
    final button = theme.elevatedButtonTheme.style;
    return theme.copyWith(
      textTheme: t.copyWith(
        displayLarge: plain(t.displayLarge),
        displayMedium: plain(t.displayMedium),
        displaySmall: plain(t.displaySmall),
        headlineLarge: plain(t.headlineLarge),
        headlineMedium: plain(t.headlineMedium),
        headlineSmall: plain(t.headlineSmall),
        titleLarge: plain(t.titleLarge),
        titleMedium: plain(t.titleMedium),
        titleSmall: plain(t.titleSmall),
        bodyLarge: plain(t.bodyLarge),
        bodyMedium: plain(t.bodyMedium),
        bodySmall: plain(t.bodySmall),
        labelLarge: plain(t.labelLarge),
        labelMedium: plain(t.labelMedium),
        labelSmall: plain(t.labelSmall),
      ),
      appBarTheme: theme.appBarTheme
          .copyWith(titleTextStyle: plain(theme.appBarTheme.titleTextStyle)),
      chipTheme: theme.chipTheme
          .copyWith(labelStyle: plain(theme.chipTheme.labelStyle)),
      elevatedButtonTheme: button == null
          ? null
          : ElevatedButtonThemeData(
              style: button.copyWith(
                textStyle: WidgetStatePropertyAll(
                    plain(button.textStyle?.resolve(const {}))),
              ),
            ),
    );
  }

  /// خطوط الموقع: Tajawal للنصوص، و Reem Kufi للعناوين الكبيرة.
  static TextTheme _textTheme(TextTheme base, Color color) {
    final body = GoogleFonts.tajawalTextTheme(base);
    TextStyle? display(TextStyle? style) =>
        style == null ? null : GoogleFonts.reemKufi(textStyle: style);
    return body
        .copyWith(
          displayLarge: display(body.displayLarge),
          displayMedium: display(body.displayMedium),
          displaySmall: display(body.displaySmall),
          headlineLarge: display(body.headlineLarge),
          headlineMedium: display(body.headlineMedium),
          headlineSmall: display(body.headlineSmall),
        )
        .apply(bodyColor: color, displayColor: color);
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brandGreen,
        secondary: AppColors.gold,
        onSecondary: AppColors.primaryDark,
        error: AppColors.danger,
        surface: Colors.white,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.darkInk),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkInk,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkInk),
        actionsIconTheme: const IconThemeData(color: AppColors.darkInk),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      // بلا لون صريح كان نص الرقائق يُرسم أبيض على الأبيض (الأحجام، البحث، الفلاتر).
      // المحدد بخلفية خضراء فاتحة كي يبقى النص الداكن مقروءاً في كل الحالات.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.brandGreen.withValues(alpha: 0.14),
        secondarySelectedColor: AppColors.gold,
        checkmarkColor: AppColors.brandGreen,
        labelStyle: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    const surface = Color(0xFF1A2A25); // Darker green-tinted surface
    const border = Color(0xFF243B33);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A1411),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brandGreenLight,
        secondary: AppColors.gold,
        onSecondary: Colors.black,
        error: AppColors.danger,
        surface: surface,
      ),
      textTheme: _textTheme(base.textTheme, Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreenLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 0.8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.brandGreenLight, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

/// ألوان تتكيف مع الوضع الليلي/النهاري لبطاقات لوحات البائع والمدير،
/// بدلاً من الدرجات الفاتحة الثابتة (مثل Colors.blue.shade50) التي تُخفي النص ليلاً.
extension AdaptiveColors on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  /// خلفية ناعمة بلون مميز: باهتة نهاراً وشفافة أغمق ليلاً.
  Color softTint(Color accent) =>
      accent.withValues(alpha: isDarkTheme ? 0.22 : 0.10);

  /// خلفية البطاقة وحدودها حسب الوضع.
  Color get cardSurface => Theme.of(this).colorScheme.surface;
  Color get cardBorder => Theme.of(this).colorScheme.outlineVariant;

  // ألوان العلامة لا ألوان Material الافتراضية (المشتقة من البنفسجي).
  /// سطح ثانوي باهت (خلفية صورة غائبة، صندوق مراجعة...).
  Color get mutedSurface =>
      isDarkTheme ? const Color(0xFF22332D) : AppColors.bgLight;

  /// نص ثانوي (عدد، تاريخ، ملاحظة) مقروء في الوضعين.
  Color get mutedText =>
      isDarkTheme ? const Color(0xFFA8B3AC) : AppColors.muted;

  /// حدود البطاقات بلون العلامة نهاراً وأخضر داكن ليلاً.
  Color get softBorder =>
      isDarkTheme ? const Color(0xFF243B33) : AppColors.border;

  /// لون التمييز (أيقونات/روابط) المقروء في الوضعين: الأخضر نهاراً والنعناعي ليلاً (الأخضر الداكن لا يُقرأ على الخلفية الليلية).
  Color get accent =>
      isDarkTheme ? const Color(0xFF5CC8A0) : AppColors.brandGreen;

  /// لون نص ذهبي مقروء: الذهبي الداكن نهاراً والذهبي ليلاً.
  Color get goldText => isDarkTheme ? AppColors.gold : AppColors.goldInk;
}
