import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// أقسام كل موظف معتمد (نفس صفحة الموقع): المدير يختار ما يعمل فيه كل موظف.
class AdminEmployeeSectionsTab extends StatefulWidget {
  const AdminEmployeeSectionsTab({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminService? service;

  @override
  State<AdminEmployeeSectionsTab> createState() =>
      _AdminEmployeeSectionsTabState();
}

class _AdminEmployeeSectionsTabState extends State<AdminEmployeeSectionsTab> {
  late final AdminService _service = widget.service ?? AdminService();
  EmployeeTeam? _team;
  final Map<int, Set<String>> _chosen = {};
  final Set<int> _saving = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final team = await _service.employeeTeam();
      if (!mounted) return;
      setState(() {
        _team = team;
        _chosen
          ..clear()
          ..addEntries(
              team.members.map((m) => MapEntry(m.id, {...m.sections})));
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الموظفين.');
    }
  }

  Future<void> _save(int id) async {
    final sections = _chosen[id] ?? {};
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('اختر قسماً واحداً على الأقل.')));
      return;
    }
    setState(() => _saving.add(id));
    try {
      final message =
          await _service.updateEmployeeSections(id, sections.toList());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final team = _team;
    if (team == null) return const Center(child: CircularProgressIndicator());
    if (team.members.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد موظفون معتمدون بعد.', icon: Icons.badge_outlined);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const AppText(
              'اختر لكل موظف الأقسام التي يعمل فيها. لا يرى الموظف غيرها في الموقع ولا في التطبيق.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final member in team.members)
            Card(
              key: ValueKey('employee-sections-${member.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (value, label) in team.sections)
                          FilterChip(
                            key: ValueKey('section-${member.id}-$value'),
                            label: Text(label),
                            selected:
                                _chosen[member.id]?.contains(value) ?? false,
                            onSelected: (on) => setState(() {
                              final set =
                                  _chosen.putIfAbsent(member.id, () => {});
                              on ? set.add(value) : set.remove(value);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        key: ValueKey('save-sections-${member.id}'),
                        onPressed: _saving.contains(member.id)
                            ? null
                            : () => _save(member.id),
                        child: const AppText('حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
