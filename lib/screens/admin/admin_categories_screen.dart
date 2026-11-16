import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AdminService _service = AdminService();
  List<Category>? _categories;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final categories = await _service.categories();
      setState(() => _categories = categories);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الأقسام.');
    }
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الحذف'),
        content: AppText(
          'حذف قسم "${category.name}" نهائياً؟\n\nما بتقدر تحذف قسم مرتبط بمنتجات أو فيه تفريعات.',
        ),
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

    try {
      await _service.deleteCategory(category.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _showFormDialog({Category? parent, Category? editing}) async {
    final controller = TextEditingController(text: editing?.name ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(
          editing != null
              ? 'تعديل "${editing.name}"'
              : (parent != null
                  ? 'قسم فرعي ضمن "${parent.name}"'
                  : 'قسم رئيسي جديد'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate('اسم القسم')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              try {
                if (editing != null) {
                  await _service.updateCategory(editing.id,
                      name: name, parentId: parent?.id);
                } else {
                  await _service.createCategory(name, parentId: parent?.id);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: AppText(e.message)));
                }
              }
            },
            child: const AppText('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('الأقسام'),
        actions: [
          IconButton(
              tooltip: context.tr('إضافة تصنيف'),
              icon: const Icon(Icons.add), onPressed: () => _showFormDialog()),
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
    if (_categories == null) {
      return const LoadingIndicator();
    }
    if (_categories!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد أقسام بعد. اضغط + لإضافة أول قسم.',
          icon: Icons.category_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _categories!.length,
      itemBuilder: (context, index) {
        final category = _categories![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.folder_outlined, color: AppColors.emerald),
                title: AppText(category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.tr('إضافة تصنيف فرعي'),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => _showFormDialog(parent: category),
                    ),
                    IconButton(
                      tooltip: context.tr('تعديل'),
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.emerald),
                      onPressed: () => _showFormDialog(editing: category),
                    ),
                    IconButton(
                      tooltip: context.tr('حذف'),
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.danger),
                      onPressed: () => _delete(category),
                    ),
                  ],
                ),
              ),
              if (category.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 24, bottom: 8, left: 8),
                  child: Column(
                    children: category.children
                        .map((child) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.subdirectory_arrow_left,
                                  size: 18, color: AppColors.muted),
                              title: AppText(child.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: context.tr('تعديل'),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: AppColors.emerald),
                                    onPressed: () => _showFormDialog(
                                        editing: child, parent: category),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('حذف'),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.danger),
                                    onPressed: () => _delete(child),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
