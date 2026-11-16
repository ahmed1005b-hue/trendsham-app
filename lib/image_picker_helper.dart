import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

/// نتيجة اختيار الصور: الصور المقبولة + رسائل عن أي صور انرفضت (وسبب رفضها)
class PickedImagesResult {
  final List<XFile> accepted;
  final List<String> errors;

  PickedImagesResult({required this.accepted, required this.errors});
}

/// مساعد موحّد لاختيار الصور بالتطبيق، بنفس قواعد السيرفر (ImageUploadService):
/// - صيغ مسموحة: JPG / PNG / WEBP فقط
/// - الحجم الأقصى: 4 ميغابايت
/// - الأبعاد: من 80×80 لحد 6000×6000
///
/// الفحص هون لتجربة استخدام أفضل (رسالة فورية بدل ما ينرفع الملف ويرفضه السيرفر)،
/// مو بديل عن فحص السيرفر - السيرفر هو الحماية الحقيقية دايماً.
class ImagePickerHelper {
  static const int maxBytes = 4 * 1024 * 1024;
  static const int minDimension = 80;
  static const int maxDimension = 6000;
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // تصغير الصور الكبيرة قبل الرفع: موبايلات اليوم بتصوّر 4000×3000+ وحجمها ممكن
  // يتخطى 4MB بسهولة. 2000 بكسل أكتر من كافي للعرض بالتطبيق والويب.
  static const double resizeMaxWidth = 2000;
  static const double resizeMaxHeight = 2000;
  static const int quality = 85;

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedImagesResult> pickMultiple() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: resizeMaxWidth,
      maxHeight: resizeMaxHeight,
      imageQuality: quality,
    );

    return _validateAll(picked);
  }

  static Future<PickedImagesResult> pickSingle(
      {ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: resizeMaxWidth,
      maxHeight: resizeMaxHeight,
      imageQuality: quality,
    );

    if (picked == null) {
      return PickedImagesResult(accepted: [], errors: []);
    }

    return _validateAll([picked]);
  }

  static Future<PickedImagesResult> _validateAll(List<XFile> files) async {
    final accepted = <XFile>[];
    final errors = <String>[];

    for (final file in files) {
      final error = await _validate(file);
      if (error == null) {
        accepted.add(file);
      } else {
        errors.add(error);
      }
    }

    return PickedImagesResult(accepted: accepted, errors: errors);
  }

  /// يرجع null لو الصورة مقبولة، أو رسالة الخطأ لو مرفوضة.
  static Future<String?> _validate(XFile file) async {
    final name = file.name.isNotEmpty
        ? file.name
        : file.path.split(Platform.pathSeparator).last;
    final extension =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';

    if (!allowedExtensions.contains(extension)) {
      return '"$name": الصيغة غير مدعومة. المسموح فقط JPG أو PNG أو WEBP.';
    }

    final size = await file.length();
    if (size > maxBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      return '"$name": حجم الصورة $mb ميغابايت، والحد الأقصى 4 ميغابايت.';
    }

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();

      if (width < minDimension || height < minDimension) {
        return '"$name": الصورة صغيرة جداً ($width×$height)، الحد الأدنى $minDimension×$minDimension.';
      }
      if (width > maxDimension || height > maxDimension) {
        return '"$name": أبعاد الصورة كبيرة جداً ($width×$height).';
      }
    } catch (_) {
      return '"$name": الملف تالف أو ليس صورة صالحة.';
    }

    return null;
  }
}
