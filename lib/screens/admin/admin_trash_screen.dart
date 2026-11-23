import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_tools_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// المحذوفات (نفس صفحة الموقع): كل ما حُذف حذفاً مؤقتاً، مع زر استرجاع.
class AdminTrashScreen extends StatefulWidget {
  const AdminTrashScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminToolsService? service;

  @override
  State<AdminTrashScreen> createState() => _AdminTrashScreenState();
}

class _AdminTrashScreenState extends State<AdminTrashScreen> {
  late final AdminToolsService _service = widget.service ?? AdminToolsService();
  String? _type;
  TrashPage? _page;
  String? _error;
  int? _restoring;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _service.trash(type: _type);
      if (mounted) {
        setState(() {
          _page = page;
          _type = page.current;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحذوفات.');
    }
  }

  Future<void> _restore(TrashItem item) async {
    setState(() => _restoring = item.id);
    try {
      final message = await _service.restore(_type!, item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر الاتصال بالسيرفر.')));
      }
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('المحذوفات')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : page == null
              ? const LoadingIndicator()
              : Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        children: [
                          for (final (value, label, count) in page.types)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                key: ValueKey('trash-type-$value'),
                                selected: value == _type,
                                label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppText(label),
                                      Text(' ($count)'),
                                    ]),
                                onSelected: (_) {
                                  setState(() => _type = value);
                                  _load();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: page.items.isEmpty
                          ? const AppStateMessage(
                              message: 'لا توجد محذوفات هنا.',
                              icon: Icons.delete_outline)
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 24),
                                itemCount: page.items.length,
                                itemBuilder: (_, i) {
                                  final item = page.items[i];
                                  return Card(
                                    key: ValueKey('trash-item-${item.id}'),
                                    child: ListTile(
                                      title: Text(item.title),
                                      subtitle: Text(
                                          [
                                            item.detail,
                                            if (item.deletedAt != null)
                                              DateFormat('yyyy-MM-dd').format(
                                                  item.deletedAt!.toLocal()),
                                          ].whereType<String>().join(' · '),
                                          style: const TextStyle(fontSize: 12)),
                                      trailing: OutlinedButton(
                                        key: ValueKey(
                                            'trash-restore-${item.id}'),
                                        onPressed: _restoring == null
                                            ? () => _restore(item)
                                            : null,
                                        child: const AppText('استرجاع'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
