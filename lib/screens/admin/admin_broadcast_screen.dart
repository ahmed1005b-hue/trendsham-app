import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_engagement_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// الإشعار الجماعي لكل العملاء (نفس صفحة الموقع): مرة كل 7 أيام، مع معاينة وتأكيد.
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminEngagementService? service;

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  late final AdminEngagementService _service =
      widget.service ?? AdminEngagementService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  final _date = DateFormat('yyyy-MM-dd HH:mm');
  BroadcastsPage? _page;
  String? _error;
  String? _formError;
  bool _confirm = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _service.broadcasts();
      if (mounted) setState(() => _page = page);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الإشعارات.');
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _formError = 'اكتب العنوان والنص.');
      return;
    }
    if (!_confirm) {
      setState(() => _formError = 'أكّد أنك تريد الإرسال لكل العملاء.');
      return;
    }
    setState(() {
      _sending = true;
      _formError = null;
    });
    try {
      final message = await _service.sendBroadcast(
          title: _title.text.trim(),
          body: _body.text.trim(),
          link: _link.text.trim());
      if (!mounted) return;
      _title.clear();
      _body.clear();
      _link.clear();
      setState(() => _confirm = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) setState(() => _formError = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('إشعار جماعي')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : page == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _audience(page),
                      if (page.nextAllowedAt == null)
                        _form()
                      else
                        Card(
                          key: const ValueKey('broadcast-wait'),
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const AppText('الإرسال التالي المتاح'),
                            subtitle: Text(
                                _date.format(page.nextAllowedAt!.toLocal())),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const AppText('الإرسالات السابقة',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: AppText('لم يُرسل أي إشعار جماعي بعد.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      for (final b in page.items) _historyCard(b),
                    ],
                  ),
                ),
    );
  }

  Widget _audience(BroadcastsPage page) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('إشعار جماعي واحد كل 7 أيام.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 6),
              Row(children: [
                const AppText('كل العملاء (يصلهم في صفحة الإشعارات)'),
                Text(': ${page.total}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Row(children: [
                const AppText('يصلهم على الهاتف (فعّلوا العروض)'),
                Text(': ${page.reachable}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ),
      );

  Widget _form() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppText('إشعار جديد لكل العملاء',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                key: const ValueKey('broadcast-title'),
                controller: _title,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.tr('العنوان')),
              ),
              TextField(
                key: const ValueKey('broadcast-body'),
                controller: _body,
                maxLength: 180,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.tr('النص')),
              ),
              TextField(
                controller: _link,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: context.tr('رابط اختياري'),
                  helperText:
                      context.tr('(صفحة في الموقع تبدأ بـ / مثل /store/4)'),
                ),
              ),
              const SizedBox(height: 10),
              const AppText('معاينة كما تظهر على الهاتف',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? '…' : _title.text,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_body.text.isEmpty ? '…' : _body.text),
                  ],
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('broadcast-confirm'),
                contentPadding: EdgeInsets.zero,
                value: _confirm,
                onChanged: (v) => setState(() => _confirm = v ?? false),
                title: const AppText('أكّد أنك تريد الإرسال لكل العملاء.'),
              ),
              if (_formError != null)
                AppText(_formError!,
                    style: const TextStyle(color: AppColors.danger)),
              FilledButton.icon(
                key: const ValueKey('broadcast-send'),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.campaign_outlined),
                label: const AppText('إرسال'),
              ),
            ],
          ),
        ),
      );

  Widget _historyCard(BroadcastItem b) => Card(
        child: ListTile(
          title: Text(b.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.body),
              const SizedBox(height: 4),
              Row(children: [
                AppText(b.sentAt != null ? 'أُرسل' : 'مجدول',
                    style: TextStyle(
                        fontSize: 12,
                        color: b.sentAt != null
                            ? AppColors.emerald
                            : const Color(0xFFC9962C))),
                Text(
                    ' · ${_date.format((b.sentAt ?? b.scheduledFor ?? DateTime.now()).toLocal())}',
                    style: const TextStyle(fontSize: 12)),
              ]),
              if (b.sentAt != null)
                Row(children: [
                  const AppText('في الإشعارات', style: TextStyle(fontSize: 12)),
                  Text(': ${b.recipients} · ',
                      style: const TextStyle(fontSize: 12)),
                  const AppText('على الهاتف', style: TextStyle(fontSize: 12)),
                  Text(': ${b.pushed}', style: const TextStyle(fontSize: 12)),
                ]),
            ],
          ),
        ),
      );
}
