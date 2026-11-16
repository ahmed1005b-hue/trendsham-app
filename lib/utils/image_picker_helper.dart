import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class PickedImagesResult {
  final List<XFile> accepted;
  final List<String> errors;

  PickedImagesResult({required this.accepted, required this.errors});
}

class PickedDocumentsResult {
  final List<XFile> accepted;
  final List<String> errors;

  PickedDocumentsResult({required this.accepted, required this.errors});
}

class ImagePickerHelper {
  static const int maxBytes = 4 * 1024 * 1024;
  static const int identityMaxBytes = 5 * 1024 * 1024;
  static const int minDimension = 80;
  static const int maxDimension = 6000;
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedIdentityExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf'
  ];
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
    if (picked == null) return PickedImagesResult(accepted: [], errors: []);
    return _validateAll([picked]);
  }

  static Future<PickedDocumentsResult> pickIdentityDocument() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedIdentityExtensions,
    );
    if (picked == null) {
      return PickedDocumentsResult(accepted: [], errors: []);
    }
    final path = picked.path;
    final name = picked.name;
    if (path == null || path.isEmpty) {
      return PickedDocumentsResult(
          accepted: [], errors: ['تعذر قراءة الملف المحدد.']);
    }
    final xfile = XFile(path, name: name);
    final ext = (name.contains('.') ? name.split('.').last : '').toLowerCase();
    if (!allowedIdentityExtensions.contains(ext)) {
      return PickedDocumentsResult(accepted: [], errors: [
        '"$name": الصيغة غير مدعومة. المسموح JPG أو PNG أو WEBP أو PDF.'
      ]);
    }
    final size = await xfile.length();
    if (size > identityMaxBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      return PickedDocumentsResult(accepted: [], errors: [
        '"$name": حجم الملف $mb ميغابايت، والحد الأقصى 5 ميغابايت.'
      ]);
    }
    if (ext == 'pdf') {
      final bytes = await xfile.readAsBytes();
      if (bytes.length < 4 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
        return PickedDocumentsResult(
            accepted: [], errors: ['"$name": ملف PDF غير صالح.']);
      }
      return PickedDocumentsResult(accepted: [xfile], errors: []);
    }
    final imageError =
        await _validateImageBytes(xfile, name, maxBytes: identityMaxBytes);
    if (imageError != null) {
      return PickedDocumentsResult(accepted: [], errors: [imageError]);
    }
    return PickedDocumentsResult(accepted: [xfile], errors: []);
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
    return _validateImageBytes(file, name, maxBytes: maxBytes);
  }

  static Future<String?> _validateImageBytes(XFile file, String name,
      {required int maxBytes}) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes) {
        return '"$name": الملف أكبر من الحد المسموح.';
      }
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
