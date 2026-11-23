import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/invitation_service.dart';
import '../../widgets/app_state_message.dart';

/// روابط دعوة البائعين والموظفين (نفس صفحة الإدارة في الموقع):
/// إنشاء الحساب العام للعملاء فقط، والبائع والموظف ينضمان برابط خاص.
class AdminInvitationsScreen extends StatefulWidget {
  const AdminInvitationsScreen({super.key});

  @override
  State<AdminInvitationsScreen> createState() => _AdminInvitationsScreenState();
}

class _AdminInvitationsScreenState extends State<AdminInvitationsScreen> {
  final _service = InvitationService();
  List<AdminInvitation>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await _service.adminList();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الدعوات.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<AdminInvitation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewInvitationSheet(),
    );
    if (created == null || !mounted) return;
    await _load();
    if (created.url != null) await _share(created);
  }

  Future<void> _share(AdminInvitation i) async {
    final text = i.role == 'seller'
        ? '${context.tr('دعوة لفتح متجرك على تريندشام:')} ${i.url}'
        : '${context.tr('دعوة للانضمام لفريق تريندشام:')} ${i.url}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _revoke(AdminInvitation i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const AppText('إلغاء الدعوة؟ لن يعمل رابطها بعد الآن.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('رجوع')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('إلغاء الدعوة')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.adminRevoke(i.id);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const AppText('دعوات الانضمام')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('invitation-new'),
        onPressed: _create,
        icon: const Icon(Icons.add_link),
        label: const AppText('دعوة جديدة'),
      ),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : items == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: AppText(
                              'إنشاء الحساب من الموقع والتطبيق للعملاء فقط. البائع والموظف ينضمان برابط دعوة تنشئه هنا وترسله لهم وحدهم.',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: AppStateMessage(
                              message: 'لا توجد دعوات بعد.',
                              icon: Icons.mail_outline),
                        ),
                      for (final i in items)
                        Card(
                          key: ValueKey('invitation-${i.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                        [
                                          i.roleLabel,
                                          if (i.name != null) i.name
                                        ].join(' — '),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Chip(
                                    label: Text(i.statusLabel,
                                        style: const TextStyle(fontSize: 12)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ]),
                                if (i.storeName != null) Text(i.storeName!),
                                if (i.phone != null || i.email != null)
                                  Text(
                                      [i.phone, i.email]
                                          .whereType<String>()
                                          .join(' · '),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted)),
                                if (i.usable && i.url != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 8, children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: i.url!));
                                        _toast('تم النسخ');
                                      },
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const AppText('نسخ'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => _share(i),
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const AppText('إرسال'),
                                    ),
                                    TextButton(
                                      onPressed: () => _revoke(i),
                                      child: const AppText('إلغاء',
                                          style: TextStyle(
                                              color: AppColors.danger)),
                                    ),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _NewInvitationSheet extends StatefulWidget {
  const _NewInvitationSheet();

  @override
  State<_NewInvitationSheet> createState() => _NewInvitationSheetState();
}

class _NewInvitationSheetState extends State<_NewInvitationSheet> {
  final _service = InvitationService();
  final _name = TextEditingController();
  final _store = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _role = 'seller';
  int _days = 7;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _service.adminCreate(
        role: _role,
        name: _name.text,
        storeName: _role == 'seller' ? _store.text : null,
        phone: _phone.text,
        email: _email.text,
        days: _days,
      );
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('دعوة جديدة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppText(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'seller', label: AppText('بائع')),
                ButtonSegment(value: 'employee', label: AppText('موظف')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: InputDecoration(
                    labelText: context.tr('لمن الدعوة؟ (اسم للتذكير)'))),
            if (_role == 'seller')
              TextField(
                  controller: _store,
                  decoration: InputDecoration(
                      labelText: context.tr('اسم المتجر (اختياري)'))),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: context.tr('رقم هاتفه (اختياري)'))),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: context.tr('بريده (اختياري)'),
                    helperText: context.tr(
                        'إذا كتبت الهاتف أو البريد، لا يقبل الدعوة إلا صاحبه.'),
                    helperMaxLines: 2)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _days,
              decoration: InputDecoration(labelText: context.tr('صالحة لمدة')),
              items: const [
                DropdownMenuItem(value: 1, child: AppText('يوم واحد')),
                DropdownMenuItem(value: 3, child: AppText('3 أيام')),
                DropdownMenuItem(value: 7, child: AppText('أسبوع')),
                DropdownMenuItem(value: 14, child: AppText('أسبوعين')),
                DropdownMenuItem(value: 30, child: AppText('شهر')),
              ],
              onChanged: (v) => setState(() => _days = v ?? 7),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_link),
              label: const AppText('إنشاء رابط الدعوة'),
            ),
          ],
        ),
      ),
    );
  }
}
