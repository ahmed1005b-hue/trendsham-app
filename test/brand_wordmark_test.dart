import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/widgets/brand_wordmark.dart';

double _contrast(Color a, Color b) {
  final l = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (l[1] + 0.05) / (l[0] + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  test('colours match the web header logo', () {
    // الويب: .ts-masthead__logo أخضر و span ذهبي؛ الداكن: أبيض و --tsd-gold
    expect(BrandWordmark.colorsFor(Brightness.light),
        (AppColors.brandGreen, AppColors.gold));
    expect(BrandWordmark.colorsFor(Brightness.dark),
        (Colors.white, const Color(0xFFE0B45A)));
  });

  testWidgets('dark-mode wordmark stays legible on the dark background',
      (tester) async {
    final bg = AppTheme.dark.scaffoldBackgroundColor;
    final (trend, sham) = BrandWordmark.colorsFor(Brightness.dark);
    expect(_contrast(trend, bg), greaterThanOrEqualTo(4.5));
    expect(_contrast(sham, bg), greaterThanOrEqualTo(4.5));
  });

  for (final dark in [false, true]) {
    testWidgets('renders "تريند" + "شام" on one line (${dark ? 'dark' : 'light'})',
        (tester) async {
      tester.view.physicalSize = const Size(320, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: const Scaffold(body: Row(children: [BrandWordmark(), Spacer()])),
      ));

      expect(find.bySemanticsLabel('تريندشام'), findsOneWidget);
      final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      expect(rich.children!.map((c) => (c as TextSpan).text), ['تريند', 'شام']);
      expect(tester.takeException(), isNull);
    });
  }
}
