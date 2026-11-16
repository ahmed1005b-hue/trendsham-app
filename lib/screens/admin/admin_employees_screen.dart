import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final AdminService _service = AdminService();
  List<Map<String, dynamic>>? _employees;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final employees = await _service.pendingEmployees();
      if (mounted) setState(() => _employees = employees);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل طلبات الموظفين.');
    }
  }

  Future<void> _review(int id, {required bool approve}) async {
    try {
      if (approve) {
        await _service.approveEmployee(id);
      } else {
        await _service.rejectEmployee(id);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('طلبات الموظفين')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : _employees == null
              ? const LoadingIndicator()
              : _employees!.isEmpty
                  ? const AppStateMessage(
                      message: 'لا توجد طلبات موظفين معلّقة.',
                      icon: Icons.badge_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _employees!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final employee = _employees![index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(employee['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  AppText(employee['phone']?.toString() ?? ''),
                                  AppText(employee['email']?.toString() ?? ''),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => _review(
                                            employee['id'] as int,
                                            approve: true,
                                          ),
                                          child: const AppText('موافقة'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _review(
                                            employee['id'] as int,
                                            approve: false,
                                          ),
                                          child: const AppText('رفض'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
