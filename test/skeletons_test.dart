import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/widgets/shimmer_loading.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  final skeletons = <String, Widget Function()>{
    'list': () => const ListSkeleton(),
    'list circle': () => const ListSkeleton(circleLeading: true, leadingSize: 44),
    'product detail': () => const ProductDetailSkeleton(),
    'store': () => const StoreSkeleton(),
  };

  for (final dark in [false, true]) {
    for (final entry in skeletons.entries) {
      testWidgets(
          '${entry.key} skeleton fits a narrow phone (${dark ? 'dark' : 'light'})',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: Scaffold(body: entry.value()),
        ));
        // الوميض يتكرر بلا نهاية، لذا نتقدم بإطارات محددة بدل pumpAndSettle
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
        expect(find.byType(ShimmerBox), findsWidgets);
        expect(find.bySemanticsLabel('جارٍ التحميل'), findsOneWidget);
      });
    }
  }
}
