import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../utils/file_share.dart';

/// خطوات طرد البائع المشتركة بين قائمة الطلبات وصفحة تفاصيل الطلب.

/// ملصق الشحنة يُطبع لكل طرد مفتوح؛ الطرد الملغي أو المرتجع لا يُشحن
bool canPrintParcelLabel(OrderItem item) =>
    item.orderId != null &&
    !const {'cancelled', 'returned'}.contains(item.parcelStatus);

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: AppText(message)));
}

/// يفتح ملصق الشحنة PDF (طباعة / حفظ / مشاركة).
Future<void> printParcelLabel(BuildContext context, SellerService service,
    int orderId, String? orderNumber) async {
  try {
    final bytes = await service.parcelLabel(orderId);
    await openPdfBytes(bytes, 'label-${orderNumber ?? orderId}.pdf');
  } on ApiException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'تعذّر تحميل ملصق الشحنة.');
  }
}

/// ينقل طرد البائع إلى حالة جديدة: تأكيد قبل الإلغاء، ورقم تتبع اختياري عند الشحن.
/// يعيد true إذا تغيّرت الحالة.
Future<bool> changeParcelStatus(BuildContext context, SellerService service,
    int orderId, String newStatus) async {
  // الإلغاء نهائي ويُبلَّغ به العميل: نطلب تأكيداً حتى لا يحدث بلمسة خاطئة
  if (newStatus == 'cancelled') {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('إلغاء الطلب؟'),
        content: const AppText(
            'الإلغاء نهائي ولا يمكن التراجع عنه، وسيُبلَّغ العميل بذلك.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نعم، ألغِ الطلب')),
        ],
      ),
    );
    if (ok != true) return false;
  }
  // عند الشحن: رقم التتبع من شركة الشحن (اختياري) ليتابع العميل طرده
  String? tracking;
  if (newStatus == 'shipped') {
    if (!context.mounted) return false;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تم الشحن'),
        content: TextField(
          key: const ValueKey('tracking-number'),
          controller: controller,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
              labelText: ctx.tr('رقم التتبع من شركة الشحن (عند الشحن)')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حفظ')),
        ],
      ),
    );
    tracking = controller.text.trim();
    controller.dispose();
    if (ok != true) return false;
  }
  try {
    await service.updateOrderStatus(orderId, newStatus,
        trackingNumber: tracking);
    if (context.mounted) _snack(context, 'تم تحديث حالة الطلب بنجاح');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'تعذّر تحديث حالة الطلب');
  }
  return false;
}
