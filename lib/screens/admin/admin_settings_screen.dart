import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AdminService _service = AdminService();
  final _commissionController = TextEditingController();
  final _storyFeeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.settings();
      _commissionController.text = data['commission_rate'].toString();
      _storyFeeController.text = data['story_fee'].toString();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الإعدادات.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final commission = int.tryParse(_commissionController.text);
    final storyFee = double.tryParse(_storyFeeController.text);
    if (commission == null || storyFee == null) {
      setState(() => _error = 'أدخل أرقام صحيحة.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _service.updateSettings(
          commissionRate: commission, storyFee: storyFee);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: AppText('تم حفظ الإعدادات.')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر حفظ الإعدادات.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('إعدادات المنصة')),
      body: _isLoading ? const LoadingIndicator() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: context.softTint(Colors.red),
                  borderRadius: BorderRadius.circular(8)),
              child: AppText(_error!,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('نسبة العمولة العامة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const AppText(
                    'تُطبَّق على كل الطلبات المسلَّمة، ما لم يكن للبائع نسبة خاصة متفاوض عليها.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commissionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context).translate('النسبة %'),
                        suffixText: '%'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('رسم نشر الستوري',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const AppText(
                    'المبلغ الذي يُخصم من محفظة البائع مقابل نشر ستوري واحدة لمدة 24 ساعة.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _storyFeeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context).translate('المبلغ'),
                        suffixText: context.tr('ل.س')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const AppText('حفظ الإعدادات'),
          ),
        ],
      ),
    );
  }
}
