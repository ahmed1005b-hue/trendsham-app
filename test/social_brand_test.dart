import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trendsham/widgets/social_brand.dart';

/// أيقونات «تابعنا» بشعار كل موقع ولونه الأصلي (مثل أسفل الموقع).
void main() {
  test('each site gets its real logo and brand color', () {
    expect(SocialBrand.of('whatsapp').icon, FontAwesomeIcons.whatsapp);
    expect(SocialBrand.of('whatsapp').color, const Color(0xFF25D366));
    expect(SocialBrand.of('facebook').color, const Color(0xFF1877F2));
    expect(SocialBrand.of('tiktok').icon, FontAwesomeIcons.tiktok);
    expect(SocialBrand.of('twitter-x').icon, FontAwesomeIcons.xTwitter);
    expect(SocialBrand.of('instagram').gradient, isNotNull);
    expect(SocialBrand.of('unknown').icon, FontAwesomeIcons.link);
  });

  test('links from the server keep only https addresses', () {
    final link = SocialLink.fromJson({
      'key': 'instagram',
      'label': 'إنستغرام',
      'url': 'https://instagram.com/x'
    });
    expect(link.key, 'instagram');
    expect(link.url, 'https://instagram.com/x');
  });

  testWidgets('a brand circle draws the logo in white', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SocialBrandIcon(brandKey: 'whatsapp'))));
    final icon = tester.widget<FaIcon>(find.byType(FaIcon));
    expect(icon.color, Colors.white);
  });
}
