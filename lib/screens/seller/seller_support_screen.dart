import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/support_service.dart';
import 'seller_support_create_screen.dart';
import 'seller_support_detail_screen.dart';
import '../../l10n/app_localizations.dart';

class SellerSupportScreen extends StatefulWidget {
  const SellerSupportScreen({super.key, this.service});

  final SupportService? service;

  @override
  State<SellerSupportScreen> createState() => _SellerSupportScreenState();
}

class _SellerSupportScreenState extends State<SellerSupportScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  List<Map<String, dynamic>> _conversations = [];
  SupportAccessState? _access;
  bool _loading = true;
  bool _accessBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final conversations = await _service.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المحادثات.';
        _loading = false;
      });
    }
    await _loadAccess();
  }

  /// بطاقة الإذن اختيارية: إن فشل تحميلها تبقى المحادثات تعمل.
  Future<void> _loadAccess() async {
    try {
      final access = await _service.getAccess();
      if (mounted) setState(() => _access = access);
    } catch (e) {
      debugPrint('support access load failed: $e');
    }
  }

  Future<void> _grant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('السماح لفريق الدعم بالدخول'),
        content: const AppText(
            'سيستطيع فريق الدعم فتح لوحة متجرك لحل المشكلة حتى تُنهي الإذن. كل ما يفعله يُسجَّل وتراه هنا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('اسمح'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _change(_service.grantAccess);
  }

  Future<void> _change(Future<SupportAccessState> Function() action) async {
    setState(() => _accessBusy = true);
    try {
      final access = await action();
      if (mounted) setState(() => _access = access);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(context.tr('تعذّر الحفظ، حاول مجدداً.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _accessBusy = false);
    }
  }

  Widget _accessCard() {
    final access = _access;
    if (access == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('support-access-card'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: access.active ? AppColors.gold : scheme.outlineVariant,
          width: access.active ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(access.active ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: access.active ? AppColors.gold : scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: AppText('دخول فريق الدعم إلى لوحة متجرك',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 8),
            AppText(
              access.active
                  ? 'مسموح الآن. يبقى الإذن حتى تُنهيه.'
                  : 'إذا واجهتك مشكلة في متجرك، اسمح لفريق الدعم بفتح لوحتك لحلها. يبقى الإذن حتى تُنهيه أنت.',
              style: TextStyle(
                fontWeight: access.active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              'لا يستطيع الفريق حتى مع الإذن: سحب الأموال، أو رؤية بياناتك البنكية ووثائق الهوية، أو تغيير كلمة السر، أو قراءة محادثات عملائك، أو حذف منتجاتك.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: access.active
                  ? FilledButton.icon(
                      key: const ValueKey('support-access-revoke'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          minimumSize: const Size.fromHeight(46)),
                      onPressed: _accessBusy
                          ? null
                          : () => _change(_service.revokeAccess),
                      icon: const Icon(Icons.block_rounded),
                      label: const AppText('إنهاء الإذن'),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('support-access-grant'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                      onPressed: _accessBusy ? null : _grant,
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const AppText('اسمح لفريق الدعم بالدخول'),
                    ),
            ),
            if (access.actions.isNotEmpty) ...[
              const Divider(height: 24),
              const AppText('ما فعله فريق الدعم في متجرك',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final action in access.actions.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(action.description,
                              style: const TextStyle(fontSize: 13))),
                      if (action.at != null)
                        Text(_shortDate(action.at!.toLocal()),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}/${two(at.month)}/${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  Widget _conversationTile(Map<String, dynamic> c) {
    return ListTile(
      leading: CircleAvatar(
        child: AppText(c['staff_name']?.substring(0, 1) ?? 'س'),
      ),
      title: AppText(
        c['subject'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            c['staff_name'] ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          AppText(
            c['last_message'] ?? '',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                overflow: TextOverflow.ellipsis),
            maxLines: 1,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            c['status'] == 'open' ? 'مفتوحة' : 'مغلقة',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: c['status'] == 'open' ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          if (c['unread_count'] != null && c['unread_count'] > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppText(
                '${c['unread_count']}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerSupportDetailScreen(
            conversationId: c['id'],
            subject: c['subject'] ?? '',
            staffName: c['staff_name'] ?? '',
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Widget> conversations;
    if (_error != null) {
      conversations = [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Center(
            child: AppText(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _load,
            child: const AppText('إعادة المحاولة'),
          ),
        ),
      ];
    } else if (_conversations.isEmpty) {
      conversations = const [
        SizedBox(height: 40),
        Icon(Icons.headset, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Center(child: AppText('لا توجد محادثات دعم بعد.')),
        Center(
          child: AppText('انقر على زر "+" لبدء محادثة جديدة.',
              style: TextStyle(color: Colors.grey)),
        ),
      ];
    } else {
      conversations = _conversations.map(_conversationTile).toList();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_accessCard(), ...conversations],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('الدعم الفني'),
        actions: [
          IconButton(
            tooltip: context.tr('تذكرة جديدة'),
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SellerSupportCreateScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
