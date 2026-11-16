import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';

/// شعار تريندشام النصي، مطابق لشعار هيدر الويب (.ts-masthead__logo):
/// "تريند" بالأخضر و"شام" بالذهبي بخط Reem Kufi عريض.
/// في الوضع الداكن: "تريند" أبيض و"شام" ذهبي فاتح (ts-dark.css).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 28});

  final double fontSize;

  /// لون "تريند" و"شام" حسب الوضع — مكشوفان للاختبارات.
  static (Color trend, Color sham) colorsFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? (Colors.white, const Color(0xFFE0B45A)) // --tsd-gold
          : (AppColors.brandGreen, AppColors.gold);

  @override
  Widget build(BuildContext context) {
    final (trend, sham) = colorsFor(Theme.of(context).brightness);
    final style = GoogleFonts.reemKufi(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: fontSize * .01,
    );

    return Semantics(
      label: 'تريندشام',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'تريند', style: style.copyWith(color: trend)),
          TextSpan(text: 'شام', style: style.copyWith(color: sham)),
        ]),
        maxLines: 1,
        // الشعار لا يكبر مع تكبير خط النظام حتى لا يزاحم أزرار الهيدر
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
