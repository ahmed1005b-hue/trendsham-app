import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';

/// شعار موقع التواصل ولونه الأصلي (نفس ألوان أسفل الموقع).
class SocialBrand {
  final FaIconData icon;
  final Color color;

  /// إنستغرام: تدرّج ألوانه بدل لون واحد
  final Gradient? gradient;

  const SocialBrand(this.icon, this.color, {this.gradient});

  static const instagramGradient = RadialGradient(
    center: Alignment(-0.4, 1.1),
    radius: 1.3,
    colors: [
      Color(0xFFFDF497),
      Color(0xFFFD5949),
      Color(0xFFD6249F),
      Color(0xFF285AEB),
    ],
    stops: [0.05, 0.45, 0.6, 0.9],
  );

  static SocialBrand of(String key) {
    switch (key) {
      case 'whatsapp':
        return const SocialBrand(FontAwesomeIcons.whatsapp, Color(0xFF25D366));
      case 'facebook':
        return const SocialBrand(FontAwesomeIcons.facebookF, Color(0xFF1877F2));
      case 'instagram':
        return const SocialBrand(FontAwesomeIcons.instagram, Color(0xFFE1306C),
            gradient: instagramGradient);
      case 'tiktok':
        return const SocialBrand(FontAwesomeIcons.tiktok, Colors.black);
      case 'twitter-x':
      case 'x':
        return const SocialBrand(FontAwesomeIcons.xTwitter, Colors.black);
      default:
        return const SocialBrand(FontAwesomeIcons.link, Color(0xFF0B5F4A));
    }
  }
}

/// دائرة بشعار الموقع ولونه الأصلي.
class SocialBrandIcon extends StatelessWidget {
  final String brandKey;
  final double size;

  const SocialBrandIcon({super.key, required this.brandKey, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final brand = SocialBrand.of(brandKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brand.gradient == null ? brand.color : null,
        gradient: brand.gradient,
        boxShadow: [
          BoxShadow(
              color: brand.color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: FaIcon(brand.icon, color: Colors.white, size: size * 0.46),
    );
  }
}

class SocialLink {
  final String key;
  final String label;
  final String url;

  const SocialLink({required this.key, required this.label, required this.url});

  factory SocialLink.fromJson(Map<String, dynamic> json) => SocialLink(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}

class SocialLinkService {
  final ApiClient _api = ApiClient();

  Future<List<SocialLink>> list() async {
    final data = await _api.get('/social-links');
    final list =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    return list
        .whereType<Map>()
        .map((m) => SocialLink.fromJson(Map<String, dynamic>.from(m)))
        .where((l) => l.url.startsWith('https://'))
        .toList();
  }
}

/// قسم «تابعنا»: حسابات تريندشام على مواقع التواصل (تُدار من إعدادات الموقع).
class FollowUsSection extends StatefulWidget {
  final String title;

  const FollowUsSection({super.key, this.title = 'تابعنا'});

  /// مصدر الروابط؛ الاختبارات تستبدله حتى لا تتصل بالإنترنت.
  @visibleForTesting
  static Future<List<SocialLink>> Function() loader = () => SocialLinkService().list();

  @override
  State<FollowUsSection> createState() => _FollowUsSectionState();
}

class _FollowUsSectionState extends State<FollowUsSection> {
  late final Future<List<SocialLink>> _links = FollowUsSection.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SocialLink>>(
      future: _links,
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <SocialLink>[];
        if (links.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            AppText(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 10,
              children: [
                for (final link in links)
                  Semantics(
                    button: true,
                    label: link.label,
                    child: Tooltip(
                      message: link.label,
                      child: InkResponse(
                        key: ValueKey('social-${link.key}'),
                        radius: 28,
                        onTap: () => launchUrl(Uri.parse(link.url),
                            mode: LaunchMode.externalApplication),
                        child: SocialBrandIcon(brandKey: link.key),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
