import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// يفتح ملف PDF من السيرفر في نافذة المعاينة (طباعة/حفظ/مشاركة).
Future<void> openPdfBytes(Uint8List bytes, String name) =>
    Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

/// يشارك ملفاً (مثل CSV) عبر تطبيقات النظام ليحفظه المستخدم أو يرسله.
Future<void> shareFileBytes(Uint8List bytes, String name, String mimeType) =>
    SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
      fileNameOverrides: [name],
    ));
