part of 'home_tab.dart';

// عناصر مساعدة للرئيسية (ضغط متحرك، أزرار الترويسة، عناوين الأقسام، عارض القصص) — منقولة كما هي.

/// بطاقة تتّسع قليلاً عند اللمس لتعطي إحساساً بالاستجابة التفاعلية.
class _PressedScale extends StatefulWidget {
  const _PressedScale({required this.child});

  final Widget child;

  @override
  State<_PressedScale> createState() => _PressedScaleState();
}

class _PressedScaleState extends State<_PressedScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double get _scale => 1.0 - (0.05 * _controller.value);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onTap,
      tooltip: AppLocalizations.of(context).translate(label),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon,
          color: isDark ? const Color(0xFF8CCFB4) : AppColors.brandGreen,
          size: 23),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF8CCFB4) : AppColors.brandGreen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: AppText(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: AppText(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فقاعة قسم مطابقة لـ .ts-catbub في الويب: قرص دائري بثلاثة ألوان متناوبة
/// (أخضر / ذهبي / بيج) مع أيقونة أو أول حرف، وتحته الاسم في سطر واحد.
class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.name,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  final String name;
  final IconData? icon;
  final int variant; // 0 | 1 | 2 مثل ts-catbub--{index % 3}
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkTheme;
    const accent = Color(0xFF5CC8A0); // --tsd-accent
    const darkGold = Color(0xFFE0B45A); // --tsd-gold
    final (Color bg, Color fg, Color ring) = switch (variant) {
      1 => dark
          ? (
              darkGold.withValues(alpha: .12),
              darkGold,
              darkGold.withValues(alpha: .25)
            )
          : (
              AppColors.goldSoft,
              AppColors.goldInk,
              AppColors.gold.withValues(alpha: .25)
            ),
      2 => dark
          ? (
              const Color(0xFF262F2A),
              const Color(0xFFE8ECE9),
              const Color(0xFF2E3833)
            )
          : (const Color(0xFFF4EEE2), AppColors.brandGreen, AppColors.border),
      _ => dark
          ? (
              accent.withValues(alpha: .12),
              accent,
              accent.withValues(alpha: .2)
            )
          : (
              const Color(0xFFE5F1EC),
              AppColors.brandGreen,
              AppColors.brandGreen.withValues(alpha: .12)
            ),
    };
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;

    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring),
                ),
                child: icon != null
                    ? Icon(icon, color: fg, size: 22)
                    : AppText(
                        initial,
                        style: GoogleFonts.reemKufi(
                            color: fg, fontSize: 20, height: 1),
                      ),
              ),
              const SizedBox(height: 5),
              AppText(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
