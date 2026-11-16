import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/seller_profile.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../seller/seller_wallet_screen.dart';

class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  final AdminService _service = AdminService();
  List<SellerProfileModel>? _sellers;
  String? _error;
  String _status = 'pending';
  final Map<String, Future<Uint8List>> _identityDocumentFutures = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final sellers = _status == 'approved'
          ? await _service.approvedSellers()
          : await _service.sellers(status: _status);
      setState(() {
        _sellers = sellers;
        _identityDocumentFutures.clear();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذر تحميل البائعين.');
    }
  }

  Widget _identityImage(SellerProfileModel seller, String side, String label) {
    final key = '${seller.id}:$side';
    final future = _identityDocumentFutures.putIfAbsent(
      key,
      () => _service.identityDocument(seller.id, side: side),
    );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FutureBuilder<Uint8List>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(color: context.cardBorder)),
                  child: const AppText('تعذر تحميل الوثيقة',
                      style: TextStyle(color: AppColors.danger, fontSize: 11)),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                    height: 110,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final bytes = snapshot.data!;
              final isPdf = bytes.length >= 4 &&
                  bytes[0] == 0x25 &&
                  bytes[1] == 0x50 &&
                  bytes[2] == 0x44 &&
                  bytes[3] == 0x46; // %PDF
              return InkWell(
                onTap: isPdf
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          builder: (context) => Dialog(
                            child: InteractiveViewer(
                                child:
                                    Image.memory(bytes, fit: BoxFit.contain)),
                          ),
                        ),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: isPdf
                          ? context.softTint(AppColors.danger)
                          : Colors.black12,
                      border: Border.all(color: context.cardBorder),
                      borderRadius: BorderRadius.circular(6)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: isPdf
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.picture_as_pdf,
                                    color: Color(0xFFD32F2F), size: 42),
                                SizedBox(height: 6),
                                AppText('ملف PDF',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD32F2F))),
                                SizedBox(height: 2),
                                AppText('راجعه من لوحة الويب لفتحه',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.muted))
                              ])
                        : Image.memory(bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.description_outlined))),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _identityDocumentPreview(SellerProfileModel seller) {
    if (!seller.hasIdentityDocument) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AppText(
          'لا توجد وثيقة هوية. لا يمكن اعتماد الهوية قبل استلام الوثيقة.',
          style: TextStyle(color: AppColors.danger, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.cardBorder)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((seller.ownerEmail ?? '').isNotEmpty)
              AppText('البريد: ${seller.ownerEmail}',
                  style: const TextStyle(fontSize: 12)),
            if (seller.identityDocumentSubmittedAt != null)
              AppText(
                  'وقت الإرسال: ${seller.identityDocumentSubmittedAt!.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            AppText('نوع الوثيقة: ${seller.identityType ?? '—'}',
                style: const TextStyle(fontSize: 12)),
            AppText('رقم الهوية/السجل: ${seller.identityNumber ?? '—'}',
                style: const TextStyle(fontSize: 12)),
            AppText('السجل التجاري: ${seller.commercialRegister ?? '—'}',
                style: const TextStyle(fontSize: 12)),
            if ((seller.storeDescription ?? '').isNotEmpty)
              AppText('وصف المتجر: ${seller.storeDescription}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            if (seller.identityReviewPending)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: AppText('بائع قديم — الهوية قيد المراجعة والمتجر نشط.',
                    style: TextStyle(
                        color: Color(0xFFB54708),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _identityImage(seller, 'front', 'الوجه الأمامي'),
            if (seller.hasIdentityDocumentBack) ...[
              const SizedBox(width: 8),
              _identityImage(seller, 'back', 'الخلفي/إضافي'),
            ],
          ],
        ),
        const SizedBox(height: 4),
        const AppText(
            'معاينة سرية — متاحة للمراجعين الإداريين فقط. اضغط للصورة لفتحها بالحجم الكامل.',
            style: TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }

  Future<void> _editCommission(SellerProfileModel seller) async {
    final controller = TextEditingController(
        text: seller.commissionRateOverride?.toString() ?? '');
    final commissionRate = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('عمولة ${seller.storeName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'أدخل نسبة خاصة من 0 إلى 100. اترك الحقل فارغاً أو اختر استعادة النسبة العامة لتطبيق عمولة المنصة.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('نسبة العمولة الخاصة'),
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, -1),
            child: const AppText('استعادة العامة'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim().isEmpty
                  ? -1
                  : int.tryParse(controller.text.trim());
              if (value == null || value < -1 || value > 100) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: AppText('أدخل نسبة صحيحة بين 0 و100.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const AppText('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (commissionRate == null || !mounted) return;

    try {
      await _service.updateSellerCommission(
          seller.id, commissionRate == -1 ? null : commissionRate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم تحديث نسبة عمولة البائع.')),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تعذر تحديث نسبة العمولة.')),
        );
      }
    }
  }

  Future<void> _approve(SellerProfileModel seller) async {
    try {
      await _service.approveSeller(seller.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _delete(SellerProfileModel seller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف البائع'),
        content: AppText(
            'سيُحذف متجر "${seller.storeName}" ومنتجاته ووثائق هويته نهائياً. '
            'يُسمح بالحذف فقط لمتجر بلا رصيد أو مبيعات أو سحوبات؛ غير ذلك استخدم "إيقاف المتجر".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف نهائي',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteSeller(seller.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
    }
  }

  /// إيقاف المتجر: بديل آمن للحذف — يختفي عن الزوار وتبقى محفظته وطلباته
  Future<void> _suspend(SellerProfileModel seller) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('إيقاف متجر "${seller.storeName}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'ستختفي منتجاته وعروضه عن الزوار ولا يمكن الشراء منه. '
              'رصيده وطلباته وسجلاته تبقى محفوظة، ويمكن إعادة التفعيل في أي وقت.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('سبب الإيقاف (يظهر للبائع)'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const AppText('تأكيد الإيقاف'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _service.suspendSeller(seller.id, reason);
      _toast('تم إيقاف المتجر.');
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _unsuspend(SellerProfileModel seller) async {
    try {
      await _service.unsuspendSeller(seller.id);
      _toast('تمت إعادة تفعيل المتجر.');
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _reject(SellerProfileModel seller) async {
    final controller = TextEditingController();
    final legacyReview = seller.identityReviewPending;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(legacyReview
            ? 'طلب إعادة إرسال هوية "${seller.storeName}"'
            : 'رفض "${seller.storeName}"'),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate(
                    legacyReview ? 'سبب طلب إعادة الإرسال' : 'سبب الرفض'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await _service.rejectSeller(seller.id, controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: AppText(e.message)));
                }
              }
            },
            child: AppText(legacyReview ? 'إرسال الطلب' : 'تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('البائعون / مراجعة الهوية')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            // خمسة تصنيفات: تمرير أفقي حتى لا تضيق على شاشات الجوال
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: AppText('طلبات جديدة')),
                  ButtonSegment(
                      value: 'identity_review', label: AppText('مراجعة هوية')),
                  ButtonSegment(value: 'approved', label: AppText('معتمدون')),
                  ButtonSegment(value: 'suspended', label: AppText('موقوفون')),
                  ButtonSegment(value: 'rejected', label: AppText('مرفوضون')),
                ],
                selected: {_status},
                onSelectionChanged: (s) {
                  setState(() => _status = s.first);
                  _load();
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.emerald,
                child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_sellers == null) {
      return const LoadingIndicator();
    }
    if (_sellers!.isEmpty) {
      return AppStateMessage(
          message: _status == 'identity_review'
              ? 'لا توجد هويات بانتظار المراجعة حالياً.'
              : 'لا يوجد بائعون بهذا التصنيف.',
          icon: Icons.storefront_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _sellers!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final seller = _sellers![index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: AppText(seller.storeName,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (seller.identityReviewPending)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: context.softTint(Colors.orange),
                            borderRadius: BorderRadius.circular(999)),
                        child: const AppText('بائع قديم',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFB54708)))),
                ]),
                if (seller.ownerName != null)
                  AppText('${seller.ownerName} - ${seller.ownerPhone ?? ''}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                _identityDocumentPreview(seller),
                if (_status == 'approved') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          seller.commissionRateOverride == null
                              ? 'العمولة الفعّالة: ${seller.commissionRate}% (العامة)'
                              : 'العمولة الفعّالة: ${seller.commissionRate}% (خاصة)',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editCommission(seller),
                        icon: const Icon(Icons.percent, size: 18),
                        label: const AppText('تعديل العمولة'),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SellerWalletScreen(
                            sellerId: seller.id,
                            sellerName: seller.storeName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const AppText('كشف الحساب'),
                    ),
                  ),
                ],
                if (seller.isSuspended) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.softTint(AppColors.danger),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AppText(
                      'موقوف — السبب: ${seller.suspensionReason ?? 'غير محدد'}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _unsuspend(seller),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const AppText('إعادة تفعيل'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SellerWalletScreen(
                                sellerId: seller.id,
                                sellerName: seller.storeName,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const AppText('كشف الحساب'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_status == 'approved' || _status == 'rejected')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_status == 'approved')
                        TextButton.icon(
                          onPressed: () => _suspend(seller),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.orange.shade800),
                          icon:
                              const Icon(Icons.pause_circle_outline, size: 18),
                          label: const AppText('إيقاف المتجر'),
                        ),
                      TextButton.icon(
                        onPressed: () => _delete(seller),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const AppText('حذف البائع'),
                      ),
                    ],
                  ),
                if (_status == 'pending' || _status == 'identity_review') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            onPressed: seller.hasIdentityDocument
                                ? () => _approve(seller)
                                : null,
                            child: AppText(seller.identityReviewPending
                                ? 'اعتماد الهوية'
                                : 'موافقة')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(seller),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger)),
                          child: AppText(seller.identityReviewPending
                              ? 'طلب إعادة إرسال'
                              : 'رفض'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
