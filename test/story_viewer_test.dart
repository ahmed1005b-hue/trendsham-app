import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/config/api_config.dart';
import 'package:trendsham/models/coupon_story.dart';
import 'package:trendsham/screens/product/product_detail_screen.dart';
import 'package:trendsham/screens/store/store_screen.dart';
import 'package:trendsham/widgets/story_viewer.dart';

StoryModel _story({String? link}) => StoryModel.fromJson({
      'id': 1,
      'image': '',
      'caption': 'عرض اليوم',
      'link_url': link,
      'is_from_platform': true,
      'expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });

Future<void> _pump(WidgetTester tester, StoryModel story) async {
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: StoryViewer(stories: [story])),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('story parses link and hides unsafe schemes', () {
    expect(_story(link: 'https://example.com/x').hasLink, isTrue);
    expect(_story(link: 'javascript:alert(1)').hasLink, isFalse);
    expect(_story().hasLink, isFalse);
  });

  test('site links open in-app screens, others do not', () {
    final site = ApiConfig.storageBaseUrl;
    expect(StoryViewer.inAppTarget(Uri.parse('$site/product/red-jacket')),
        isA<ProductDetailScreen>());
    expect(StoryViewer.inAppTarget(Uri.parse('$site/store/12')),
        isA<StoreScreen>());
    expect(StoryViewer.inAppTarget(Uri.parse('https://example.com/product/x')),
        isNull);
    expect(StoryViewer.inAppTarget(Uri.parse('$site/cart')), isNull);
  });

  testWidgets('link button shows only when the story has a link',
      (tester) async {
    await _pump(tester, _story(link: 'https://example.com/sale'));
    expect(find.byKey(const ValueKey('story-link')), findsOneWidget);

    await _pump(tester, _story());
    expect(find.byKey(const ValueKey('story-link')), findsNothing);
  });
}
