import 'package:flutter/material.dart';
import '../../config/legal_content.dart';
import '../../l10n/app_localizations.dart';

enum LegalPageType { terms, privacy, refundPolicy }

class LegalScreen extends StatelessWidget {
  final LegalPageType type;

  const LegalScreen({super.key, required this.type});

  String get _title => switch (type) {
        LegalPageType.terms => 'الشروط والأحكام',
        LegalPageType.privacy => 'سياسة الخصوصية',
        LegalPageType.refundPolicy => 'سياسة الإرجاع والاستبدال',
      };

  @override
  Widget build(BuildContext context) {
    // النص العربي هو المفتاح؛ AppText يترجمه من assets/l10n مثل باقي الواجهة
    final sections = switch (type) {
      LegalPageType.terms => LegalContent.terms,
      LegalPageType.privacy => LegalContent.privacy,
      LegalPageType.refundPolicy => LegalContent.refundPolicy,
    };
    const disclaimer = LegalContent.disclaimer;
    return Scaffold(
      appBar: AppBar(title: AppText(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: AppText(
              disclaimer,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      section.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      section.body,
                      style: TextStyle(
                          height: 1.8,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          AppText(
            'آخر تحديث: ${DateTime.now().year}',
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
