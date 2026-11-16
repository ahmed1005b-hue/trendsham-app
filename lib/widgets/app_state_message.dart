import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../config/theme.dart';

class AppStateMessage extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  const AppStateMessage({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            AppText(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                  onPressed: onRetry, child: const AppText('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.brandGreen),
    );
  }
}
