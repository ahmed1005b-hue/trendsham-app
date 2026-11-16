import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../widgets/app_state_message.dart';

/// أسئلة العملاء على منتجات البائع مع الرد عليها.
class SellerQuestionsScreen extends StatefulWidget {
  const SellerQuestionsScreen({super.key, this.service});

  final SellerService? service;

  @override
  State<SellerQuestionsScreen> createState() => _SellerQuestionsScreenState();
}

class _SellerQuestionsScreenState extends State<SellerQuestionsScreen> {
  late final SellerService _service = widget.service ?? SellerService();
  List<Map<String, dynamic>>? _questions;
  String? _error;
  bool _unansweredOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _service.questions();
      if (mounted) setState(() => _questions = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الأسئلة.');
    }
  }

  Future<void> _answer(Map<String, dynamic> question) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('الرد على السؤال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('${question['question']}',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('ردك'),
                  border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نشر الرد')),
        ],
      ),
    );
    final text = controller.text.trim();
    if (ok != true || text.length < 2) return;
    try {
      await _service.answerQuestion((question['id'] as num).toInt(), text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تم نشر ردك على السؤال.')));
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
      appBar: AppBar(title: const AppText('أسئلة العملاء')),
      body: Column(
        children: [
          SwitchListTile(
            value: _unansweredOnly,
            onChanged: (v) => setState(() => _unansweredOnly = v),
            title: const AppText('غير المُجاب عنها فقط'),
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load, color: AppColors.emerald, child: _body()),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_questions == null) return const LoadingIndicator();
    final questions = _unansweredOnly
        ? _questions!.where((q) => q['has_answer'] != true).toList()
        : _questions!;
    if (questions.isEmpty) {
      return AppStateMessage(
          message: _unansweredOnly
              ? 'لا توجد أسئلة بانتظار ردك.'
              : 'لم يسأل أحد عن منتجاتك بعد.',
          icon: Icons.question_answer_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final q = questions[index];
        final answers = (q['answers'] as List? ?? []).whereType<Map>().toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('${q['product_name']}',
                    style: const TextStyle(
                        color: AppColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                AppText('${q['question']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                AppText('${q['customer_name'] ?? ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                for (final a in answers)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppText(
                        '${a['is_seller_answer'] == true ? 'ردك: ' : ''}${a['answer']}'),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => _answer(q),
                    icon: const Icon(Icons.reply),
                    label: AppText(answers.isEmpty ? 'رد' : 'رد إضافي'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
