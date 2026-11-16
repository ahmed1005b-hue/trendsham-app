import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import 'api_exception.dart';
import 'auth_token_storage.dart';

class ApiClient {
  /// لغة الواجهة الحالية؛ تُرسل مع كل طلب ليرد السيرفر برسائله بنفس اللغة.
  /// يضبطها [AppSettingsProvider] عند التحميل وعند تغيير اللغة.
  static String languageCode = 'ar';

  final AuthTokenStorage _tokenStorage = AuthTokenStorage();

  Future<String?> get token => _tokenStorage.read();

  Future<void> saveToken(String token) => _tokenStorage.write(token);

  Future<void> clearToken() => _tokenStorage.delete();

  Future<Map<String, String>> _headers({
    bool withAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-App-Locale': languageCode,
    };

    if (withAuth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }

    if (extraHeaders != null) headers.addAll(extraHeaders);
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    if (!ApiConfig.isTransportAllowed(
      ApiConfig.baseUrl,
      allowInsecureHttp: ApiConfig.allowInsecureHttp,
    )) {
      throw const ApiException(
        'نسخة الإنتاج تتطلب عنوان API آمنًا يبدأ بـ HTTPS.',
      );
    }

    Map<String, String>? cleanQuery;
    if (query != null) {
      cleanQuery = {};
      query.forEach((k, v) {
        if (v != null) cleanQuery![k] = v.toString();
      });
    }
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: cleanQuery);
  }

  Future<http.Response> _send(
      Future<http.Response> Function() requestFn) async {
    try {
      return await requestFn().timeout(const Duration(seconds: 15));
    } on SocketException catch (_) {
      throw const ApiException(
        'يتعذر الاتصال بالسيرفر. يرجى التأكد من تشغيل السيرفر والاتصال بالشبكة.',
      );
    } on http.ClientException catch (_) {
      throw const ApiException(
        'فشل الاتصال بالسيرفر. يرجى التأكد من صحة الرابط والشبكة.',
      );
    } on TimeoutException catch (_) {
      throw const ApiException(
        'انتهت مهلة الاتصال بالسيرفر (Timeout). يرجى المحاولة لاحقاً.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذّر الاتصال بالسيرفر: $e');
    }
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query,
      bool withAuth = true,
      Map<String, String>? headers}) async {
    final res = await _send(() async {
      return http.get(_uri(path, query),
          headers: await _headers(withAuth: withAuth, extraHeaders: headers));
    });
    return _handle(res, withAuth: withAuth);
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? body,
      bool withAuth = true,
      Map<String, String>? headers}) async {
    final res = await _send(() async {
      return http.post(
        _uri(path),
        headers: await _headers(withAuth: withAuth, extraHeaders: headers),
        body: jsonEncode(body ?? {}),
      );
    });
    return _handle(res, withAuth: withAuth);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await _send(() async {
      return http.put(
        _uri(path),
        headers: await _headers(),
        body: jsonEncode(body ?? {}),
      );
    });
    return _handle(res);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final res = await _send(() async {
      return http.delete(
        _uri(path),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      );
    });
    return _handle(res);
  }

  /// لإرسال فورم فيه صور (multipart) - يستخدم لإنشاء/تعديل منتج.
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<XFile>? images,
    Map<String, XFile>? files,
    String method = 'POST',
    String imageParamName = 'images[]',
  }) async {
    final res = await _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));

      final t = await token;
      if (t != null) request.headers['Authorization'] = 'Bearer $t';
      request.headers['Accept'] = 'application/json';
      request.headers['X-App-Locale'] = languageCode;

      request.fields.addAll(fields);
      if (method == 'PUT') {
        request.fields['_method'] = 'PUT';
      }

      if (images != null && images.isNotEmpty) {
        for (final image in images) {
          request.files.add(
              await http.MultipartFile.fromPath(imageParamName, image.path));
        }
      }
      if (files != null) {
        for (final entry in files.entries) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value.path),
          );
        }
      }

      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    return _handle(res);
  }

  Future<dynamic> postMultipartNoAuth(
    String path, {
    required Map<String, String> fields,
    required Map<String, XFile> files,
  }) async {
    final res = await _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers['Accept'] = 'application/json';
      request.headers['X-App-Locale'] = languageCode;
      request.fields.addAll(fields);
      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    return _handle(res, withAuth: false);
  }

  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final res = await _send(() async {
      return http.get(_uri(path, query), headers: await _headers());
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }

    final bodyText = _normalizeBodyText(res.bodyBytes);
    dynamic decoded;
    try {
      decoded = bodyText.isNotEmpty ? jsonDecode(bodyText) : null;
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode == 401) {
      throw const ApiException('انتهت صلاحية الجلسة، سجّل دخولك من جديد.',
          statusCode: 401);
    }
    final message = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : 'تعذّر تحميل الوثيقة.';
    throw ApiException(message, statusCode: res.statusCode);
  }

  String _normalizeBodyText(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    return text;
  }

  dynamic _decodeJsonBody(http.Response res) {
    final bodyText = _normalizeBodyText(res.bodyBytes);
    if (bodyText.isEmpty) return null;
    try {
      return jsonDecode(bodyText);
    } on FormatException {
      final trimmed = bodyText.trimLeft();
      final objectStart = trimmed.indexOf('{');
      final arrayStart = trimmed.indexOf('[');
      var start = -1;
      if (objectStart >= 0 && arrayStart >= 0) {
        start = objectStart < arrayStart ? objectStart : arrayStart;
      } else if (objectStart >= 0) {
        start = objectStart;
      } else if (arrayStart >= 0) {
        start = arrayStart;
      }
      if (start > 0) {
        return jsonDecode(trimmed.substring(start));
      }
      rethrow;
    }
  }

  dynamic _handle(http.Response res, {bool withAuth = true}) {
    final decoded = _decodeJsonBody(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    if (res.statusCode == 401 && withAuth) {
      throw const ApiException('انتهت صلاحية الجلسة، سجّل دخولك من جديد.',
          statusCode: 401);
    }

    if (res.statusCode == 422 && decoded is Map && decoded['errors'] != null) {
      final errors = Map<String, dynamic>.from(decoded['errors']);
      final firstError = (errors.values.first as List).first.toString();
      throw ApiException(firstError, statusCode: 422, errors: errors);
    }

    final message = (decoded is Map && decoded['message'] != null)
        ? decoded['message'].toString()
        : 'حدث خطأ، حاول مرة أخرى.';

    throw ApiException(message, statusCode: res.statusCode);
  }
}
