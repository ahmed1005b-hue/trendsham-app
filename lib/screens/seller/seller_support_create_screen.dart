import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/support_service.dart';
import '../../l10n/app_localizations.dart';

class SellerSupportCreateScreen extends StatefulWidget {
  const SellerSupportCreateScreen({super.key});

  @override
  State<SellerSupportCreateScreen> createState() =>
      _SellerSupportCreateScreenState();
}

class _SellerSupportCreateScreenState extends State<SellerSupportCreateScreen> {
  final SupportService _service = SupportService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _selectedStaffId = '1';

  final List<Map<String, String>> _staffList = [
    {'id': '1', 'name': 'الدعم الفني'},
    {'id': '2', 'name': 'إدارة المنصة'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال الموضوع.');
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال نص الرسالة.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.createConversation(
        staffId: int.parse(_selectedStaffId),
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('رسالة دعم جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'اختر الموظف',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStaffId,
                    items: _staffList
                        .map((s) => DropdownMenuItem<String>(
                              value: s['id'],
                              child: AppText(s['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedStaffId = v;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: context.tr('الموظف'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppText(
                    'الموضوع',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: context.tr('اكتب موضوع الرسالة.'),
                    ),
                    maxLength: 200,
                  ),
                  const SizedBox(height: 16),
                  const AppText(
                    'رسالتك',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: context.tr('اكتب رسالتك هنا.'),
                    ),
                    maxLength: 1000,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.softTint(Colors.red),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: AppText(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const AppText('إرسال الرسالة'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
