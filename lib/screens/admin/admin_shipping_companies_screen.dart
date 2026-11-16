import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminShippingCompaniesScreen extends StatefulWidget {
  const AdminShippingCompaniesScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  State<AdminShippingCompaniesScreen> createState() =>
      _AdminShippingCompaniesScreenState();
}

class _AdminShippingCompaniesScreenState
    extends State<AdminShippingCompaniesScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  List<Map<String, dynamic>>? _companies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _service.shippingCompanies();
      if (mounted) setState(() => _companies = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل شركات الشحن.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('شركة شحن جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).translate('اسم الشركة')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)
                      .translate('رقم الهاتف (اختياري)')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('إضافة')),
        ],
      ),
    );
    if (created != true || name.text.trim().isEmpty) return;
    await _run(() => _service.createShippingCompany(name.text.trim(),
        phone: phone.text.trim()));
  }

  Future<void> _delete(Map<String, dynamic> company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الحذف'),
        content: AppText('حذف شركة "${company['name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
        () => _service.deleteShippingCompany((company['id'] as num).toInt()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('شركات الشحن'),
        actions: [
          IconButton(
              tooltip: context.tr('إضافة شركة'),
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_companies == null) return const LoadingIndicator();
    if (_companies!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد شركات شحن. اضغط + لإضافة واحدة.',
          icon: Icons.local_shipping_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _companies!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _companies![index];
        final id = (c['id'] as num).toInt();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined,
                color: AppColors.emerald),
            title: AppText('${c['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: c['phone'] != null ? AppText('${c['phone']}') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: c['is_active'] == true,
                  activeThumbColor: AppColors.emerald,
                  onChanged: (_) =>
                      _run(() => _service.toggleShippingCompany(id)),
                ),
                IconButton(
                  tooltip: context.tr('حذف'),
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _delete(c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
