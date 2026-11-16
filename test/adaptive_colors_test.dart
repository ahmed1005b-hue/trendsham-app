import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trendsham/config/theme.dart';

double _contrast(Color a, Color b) {
  final l = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (l[1] + 0.05) / (l[0] + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  for (final dark in [false, true]) {
    testWidgets(
        'adaptive text colors stay readable on adaptive surfaces (${dark ? 'dark' : 'light'})',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));

      for (final surface in [ctx.cardSurface, ctx.mutedSurface]) {
        expect(_contrast(ctx.mutedText, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(ctx.goldText, surface), greaterThanOrEqualTo(4.5));
      }
      // السطح الثانوي يجب أن يبقى داكناً ليلاً وفاتحاً نهاراً (لا "جزر ضوء")
      expect(ctx.mutedSurface.computeLuminance() < 0.2, dark);
      expect(ctx.cardSurface.computeLuminance() < 0.2, dark);
    });
  }
}
