import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../screens/legal/legal_screen.dart';
import '../services/consent_service.dart';
import '../l10n/app_localizations.dart';

class ConsentBanner extends StatefulWidget {
  const ConsentBanner({super.key});

  @override
  State<ConsentBanner> createState() => _ConsentBannerState();
}

class _ConsentBannerState extends State<ConsentBanner> {
  bool _visible = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasChoice = await ConsentService.hasChoice();
    if (!mounted) return;
    setState(() {
      _visible = !hasChoice;
      _loaded = true;
    });
  }

  Future<void> _choose(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_visible) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(14),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'خصوصيتك تهمنا',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppText(
                        'نستخدم ملفات تعريف الارتباط والتخزين المحلي لتحسين تجربتك. بالمتابعة فإنك توافق على ',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalPageType.terms)),
                        ),
                        child: const AppText('الشروط والأحكام', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark, decoration: TextDecoration.underline)),
                      ),
                      AppText(' و', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalPageType.privacy)),
                        ),
                        child: const AppText('سياسة الخصوصية', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark, decoration: TextDecoration.underline)),
                      ),
                      AppText('.', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _choose(ConsentService.reject), child: const AppText('رفض'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(onPressed: () => _choose(ConsentService.accept), child: const AppText('موافق'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
