import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/product_review.dart';
import 'package:trendsham/screens/product/product_detail_screen.dart';

void main() {
  group('ProductReview parsing', () {
    test('parses the API review payload into a review item', () {
      final review = ProductReview.fromJson({
        'id': 12,
        'rating': 5,
        'comment': 'منتج ممتاز',
        'customer_name': 'أحمد',
        'verified_purchase': true,
        'created_at': '2024-06-01T12:30:00.000Z',
      });

      expect(review.id, 12);
      expect(review.rating, 5);
      expect(review.customerName, 'أحمد');
      expect(review.verifiedPurchase, isTrue);
      expect(review.comment, 'منتج ممتاز');
      expect(review.createdAt, isNotNull);
    });
  });

  group('ProductReviewsSection states', () {
    testWidgets('shows empty state without fabricated average values',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ProductReviewsSection(
              averageRating: null,
              reviewsCount: 0,
              reviews: [],
              isLoading: false,
              isLoadingMore: false,
              hasNextPage: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('لا توجد تقييمات'), findsNWidgets(2));
      expect(find.text('التقييمات غير متاحة حالياً'), findsNothing);

      final reviewButton = find.byIcon(Icons.rate_review_outlined);
      expect(reviewButton, findsOneWidget);
      await tester.ensureVisible(reviewButton);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('التقييم بالنجوم:'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    testWidgets('shows the loading state on initial fetch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ProductReviewsSection(
              averageRating: null,
              reviewsCount: 0,
              reviews: [],
              isLoading: true,
              isLoadingMore: false,
              hasNextPage: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('جاري تحميل التقييمات...'), findsOneWidget);
    });
  });
}
