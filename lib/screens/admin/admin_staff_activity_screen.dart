import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// سجل نشاط الفريق للمدير (نفس صفحة الموقع): من فعل ماذا ومتى.
class AdminStaffActivityScreen extends StatefulWidget {
  const AdminStaffActivityScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminService? service;

  @override
  State<AdminStaffActivityScreen> createState() =>
      _AdminStaffActivityScreenState();
}

class _AdminStaffActivityScreenState extends State<AdminStaffActivityScreen> {
  late final AdminService _service = widget.service ?? AdminService();
  final List<StaffActivityEntry> _entries = [];
  List<({int id, String name, bool isAdmin})> _staff = const [];
  List<(String, String)> _groups = const [];
  int? _userId;
  String? _group;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.staffActivity(
          userId: _userId, group: _group, page: more ? _page + 1 : 1);
      if (!mounted) return;
      setState(() {
        if (!more) _entries.clear();
        _entries.addAll(page.entries);
        _staff = page.staff;
        _groups = page.groups;
        _page = page.currentPage;
        _lastPage = page.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل السجل.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(DateTime? at) {
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  /// «مدير» أو «موظف» بلغة القارئ.
  String _roleLabel(bool isAdmin) =>
      AppLocalizations.of(context).translate(isAdmin ? 'مدير' : 'موظف');

  IconData _icon(String action) => switch (action.split('.').first) {
        'order' => Icons.receipt_long_outlined,
        'product' => Icons.inventory_2_outlined,
        'support' => Icons.support_agent,
        'chat' => Icons.chat_outlined,
        'return' => Icons.assignment_return_outlined,
        _ => Icons.history,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('سجل نشاط الفريق')),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int?>(
            key: const ValueKey('activity-person'),
            initialValue: _userId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.translate('الشخص'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: AppText('الكل')),
              for (final member in _staff)
                DropdownMenuItem<int?>(
                  value: member.id,
                  child: Text('${member.name} — ${_roleLabel(member.isAdmin)}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              _userId = value;
              _load();
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, label) in [
                  (null, l.translate('الكل')),
                  ..._groups
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _group == value,
                      onSelected: (_) {
                        _group = value;
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null && _entries.isEmpty) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد نشاط مسجّل بهذه التصفية.', icon: Icons.history);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.emerald,
      child: ListView.separated(
        itemCount: _entries.length + (_page < _lastPage ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                onPressed: _loading ? null : () => _load(more: true),
                child: const AppText('عرض المزيد'),
              ),
            );
          }
          final entry = _entries[index];
          return ListTile(
            key: ValueKey('activity-${entry.id}'),
            leading: Icon(_icon(entry.action), color: AppColors.emerald),
            title: Text(entry.description),
            subtitle: Text(
                '${entry.actorName} · ${_roleLabel(entry.isAdmin)} · ${_time(entry.createdAt)}'),
          );
        },
      ),
    );
  }
}
