import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/product_question.dart';
import '../services/product_service.dart';
import '../services/api_exception.dart';
import '../utils/auth_prompt.dart';
import 'app_state_message.dart';

/// قسم "الأسئلة والأجوبة" (Soru-Cevap) أسفل صفحة المنتج - بنمط Trendyol.
/// يدير التحميل، طرح سؤال، الإجابة، التصويت "مفيد"، والحذف بشكل مستقل.
class ProductQuestionsSection extends StatefulWidget {
  final String slug;

  const ProductQuestionsSection({super.key, required this.slug});

  @override
  State<ProductQuestionsSection> createState() =>
      _ProductQuestionsSectionState();
}

class _ProductQuestionsSectionState extends State<ProductQuestionsSection> {
  final ProductService _productService = ProductService();
  final TextEditingController _askController = TextEditingController();
  final Map<int, TextEditingController> _answerControllers = {};

  final List<ProductQuestion> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _askController.dispose();
    for (final c in _answerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _productService.questions(widget.slug);
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(result.questions);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الأسئلة.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// يستبدل سؤالاً داخل القائمة بنسخة معدّلة (الموديل غير قابل للتغيير).
  ProductQuestion _replace(int id, ProductQuestion Function(ProductQuestion) f) {
    final idx = _questions.indexWhere((q) => q.id == id);
    if (idx == -1) return _questions.firstWhere((q) => q.id == id);
    final updated = f(_questions[idx]);
    _questions[idx] = updated;
    return updated;
  }

  Future<void> _ask() async {
    final text = _askController.text.trim();
    if (text.length < 5) {
      _toast('اكتب سؤالك (5 أحرف على الأقل).');
      return;
    }
    final ok = await showAuthRequiredDialog(context);
    if (!ok || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final question = await _productService.askQuestion(widget.slug, text);
      if (!mounted) return;
      setState(() => _questions.insert(0, question));
      _askController.clear();
      _toast('تم إرسال سؤالك، شكراً لك!');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر إرسال السؤال.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _answer(int questionId) async {
    final controller = _answerControllers[questionId];
    final text = (controller?.text ?? '').trim();
    if (text.length < 2) {
      _toast('اكتب إجابتك.');
      return;
    }
    final ok = await showAuthRequiredDialog(context);
    if (!ok || !mounted) return;

    try {
      final answer = await _productService.answerQuestion(questionId, text);
      if (!mounted) return;
      setState(() {
        _replace(questionId, (q) => ProductQuestion(
              id: q.id,
              question: q.question,
              askerName: q.askerName,
              helpfulCount: q.helpfulCount,
              isHelpful: q.isHelpful,
              isAnswered: true,
              canDelete: q.canDelete,
              createdAt: q.createdAt,
              answers: [...q.answers, answer],
            ));
        controller?.clear();
      });
      _toast('تم نشر إجابتك.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر إرسال الإجابة.');
    }
  }

  Future<void> _toggleHelpful(ProductQuestion q) async {
    final ok = await showAuthRequiredDialog(context);
    if (!ok || !mounted) return;
    try {
      final result = await _productService.toggleQuestionHelpful(q.id);
      if (!mounted) return;
      setState(() {
        _replace(q.id, (e) => ProductQuestion(
              id: e.id,
              question: e.question,
              askerName: e.askerName,
              helpfulCount: result.helpfulCount,
              isHelpful: result.isHelpful,
              isAnswered: e.isAnswered,
              canDelete: e.canDelete,
              createdAt: e.createdAt,
              answers: e.answers,
            ));
      });
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر تحديث التصويت.');
    }
  }

  Future<void> _delete(ProductQuestion q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف السؤال'),
        content: const AppText('هل تريد حذف هذا السؤال فعلاً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _productService.deleteQuestion(q.id);
      if (!mounted) return;
      setState(() => _questions.removeWhere((e) => e.id == q.id));
      _toast('تم حذف السؤال.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر حذف السؤال.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(msg)));
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: isDark ? const Color(0xFF8CCFB4) : AppColors.primary, size: 20),
              const SizedBox(width: 6),
              const AppText('الأسئلة والأجوبة',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          _buildAskBox(),
          const SizedBox(height: 8),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: isDark ? const Color(0xFF8CCFB4) : AppColors.primary),
                ),
              ),
            )
          else if (_error != null)
            AppStateMessage(message: _error!, onRetry: _load)
          else if (_questions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: AppText('لا توجد أسئلة بعد. كن أول من يسأل!',
                    style:
                        TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              ),
            )
          else
            ..._questions.map(_buildQuestionCard),
        ],
      ),
    );
  }

  Widget _buildAskBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _askController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: context.tr('اكتب سؤالك عن المنتج...'),
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _ask,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: AppText(_isSubmitting ? 'جاري الإرسال...' : 'اسأل'),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
          ),
        ),
      ],
    );
  }


  Widget _buildQuestionCard(ProductQuestion q) {
    _answerControllers.putIfAbsent(q.id, () => TextEditingController());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.question_answer_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(q.question,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (q.askerName.isNotEmpty) ...[
                          AppText(q.askerName,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        if (q.isAnswered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.goldSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const AppText('تمت الإجابة',
                                style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        const Spacer(),
                        if (q.canDelete)
                          InkWell(
                            onTap: () => _delete(q),
                            child: const Icon(Icons.delete_outline,
                                color: AppColors.danger, size: 16),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (q.answers.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...q.answers.map(_buildAnswerTile),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => _toggleHelpful(q),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        q.isHelpful
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
                        size: 15,
                        color:
                            q.isHelpful ? AppColors.primary : AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      AppText(
                        q.isHelpful ? 'مفيد (${q.helpfulCount})' : 'مفيد',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              q.isHelpful ? AppColors.primary : AppColors.muted,
                          fontWeight: q.isHelpful
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAnswerField(q),
                child: const AppText('أجب',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _showAnswerField(ProductQuestion q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('إجابتك على السؤال',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              AppText(q.question,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _answerControllers[q.id],
                maxLines: 3,
                decoration: InputDecoration(hintText: context.tr('اكتب إجابتك...')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _answer(q.id);
                  },
                  child: const AppText('إرسال الإجابة'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnswerTile(ProductQuestionAnswer a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.isSellerAnswer ? AppColors.goldSoft : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: a.isSellerAnswer ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                a.isSellerAnswer
                    ? Icons.storefront_outlined
                    : Icons.person_outline,
                size: 14,
                color: a.isSellerAnswer
                    ? AppColors.primaryDark
                    : AppColors.muted,
              ),
              const SizedBox(width: 6),
              AppText(
                a.isSellerAnswer ? 'البائع' : a.authorName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: a.isSellerAnswer
                      ? AppColors.primaryDark
                      : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppText(a.answer,
              style: const TextStyle(fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}

