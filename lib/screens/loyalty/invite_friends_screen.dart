import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/loyalty_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/shimmer_loading.dart';

/// «دعوة صديق»: الكود والرابط للمشاركة، إدخال كود صديق، ومن انضم بدعوتك.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final _service = ReferralService();
  final _code = TextEditingController();

  ReferralSummary? _summary;
  bool _loading = true;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.fetchSummary();
      if (mounted) setState(() => _summary = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل صفحة الدعوة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: AppText('تم النسخ')));
  }

  Future<void> _share(ReferralSummary s) async {
    await SharePlus.instance.share(ShareParams(text: s.shareText));
  }

  Future<void> _apply() async {
    final code = _code.text.trim();
    if (code.isEmpty || _applying) return;
    setState(() => _applying = true);
    try {
      final message = await _service.apply(code);
      if (!mounted) return;
      _code.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const AppText('دعوة صديق')),
      body: _loading && s == null
          ? const ListSkeleton(
              itemCount: 4, leadingSize: 44, circleLeading: true)
          : _error != null && s == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AppText(_error!),
                    TextButton(
                        onPressed: _refresh,
                        child: const AppText('إعادة المحاولة')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _hero(s!),
                      const SizedBox(height: 12),
                      _stats(s),
                      const SizedBox(height: 12),
                      _steps(s),
                      const SizedBox(height: 12),
                      if (s.referredByName != null)
                        AppText(
                          'انضممت بدعوة من ${s.referredByName} — ${s.referredByStatusLabel}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        )
                      else if (s.canApply)
                        _applyForm(),
                      const SizedBox(height: 20),
                      const AppText('أصدقاء دعوتهم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      if (s.invited.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: AppText(
                              'لم ينضم أحد بعد. شارك رابطك مع أصدقائك.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ...s.invited.map(_friendRow),
                    ],
                  ),
                ),
    );
  }

  Widget _hero(ReferralSummary s) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B5F4A), Color(0xFF073D30)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppText('ادعُ أصدقاءك واحصلا معاً على ${pointsLabel(s.rewardPoints)}',
              style: const TextStyle(
                  color: Color(0xFFF1D9A0),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const AppText('كودك:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3),
              ),
            ),
            IconButton(
              onPressed: () => _copy(s.code),
              tooltip: context.tr('نسخ'),
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC9962C)),
              onPressed: () => _share(s),
              icon: const Icon(Icons.share_rounded),
              label: const AppText('شارك رابط الدعوة'),
            ),
          ),
        ]),
      );

  Widget _stats(ReferralSummary s) => Row(children: [
        _stat('${s.joined}', 'صديق انضم'),
        const SizedBox(width: 8),
        _stat('${s.rewarded}', 'وصله أول طلب'),
        const SizedBox(width: 8),
        _stat('${s.pointsEarned}', 'نقطة ربحتها'),
      ]);

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            AppText(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      );

  Widget _steps(ReferralSummary s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFC9962C).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFC9962C).withValues(alpha: 0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppText('كيف تعمل؟',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const AppText('1. أرسل رابطك أو كودك لصديق لم يسجّل بعد.',
              style: TextStyle(fontSize: 13)),
          const AppText('2. يسجّل صديقك ويُدخل كودك قبل أول طلب له.',
              style: TextStyle(fontSize: 13)),
          AppText(
            '3. عندما يصله أول طلب بقيمة ${s.minOrder.toStringAsFixed(0)} ل.س أو أكثر، تُضاف ${pointsLabel(s.rewardPoints)} لك وله.',
            style: const TextStyle(fontSize: 13),
          ),
        ]),
      );

  Widget _applyForm() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppText('هل دعاك صديق؟ أدخل كوده',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: context.tr('كود الدعوة'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _apply(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _applying ? null : _apply,
            child: const AppText('تأكيد'),
          ),
        ]),
      ]);

  Widget _friendRow(InvitedFriend f) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppColors.emerald.withValues(alpha: 0.12),
          child: Icon(f.rewarded ? Icons.check_rounded : Icons.person_outline,
              color: AppColors.emerald),
        ),
        title: Text(f.name),
        subtitle: AppText('انضم في ${f.joinedAt}'),
        trailing: Text(
          f.statusLabel,
          style: TextStyle(
            fontSize: 12,
            color: f.rewarded ? AppColors.emerald : AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
