import 'package:geolocator/geolocator.dart';

/// فشل تحديد الموقع برسالة جاهزة للمستخدم.
class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
  @override
  String toString() => message;
}

/// يعيد (خط العرض، خط الطول) — قابل للاستبدال في الاختبارات.
typedef LocationLookup = Future<(double, double)> Function();

/// "موقعي الحالي": يطلب الإذن عند الضغط فقط، ويعطي رسالة واضحة لكل حالة رفض.
Future<(double, double)> currentDeviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationFailure('خدمة الموقع متوقفة في الهاتف. شغّلها ثم حاول مجدداً.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationFailure('لم يُسمح بالوصول إلى الموقع. يكفي العنوان المكتوب.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationFailure(
        'الوصول إلى الموقع مرفوض دائماً. فعّله من إعدادات التطبيق، أو اكتفِ بالعنوان المكتوب.');
  }
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (pos.latitude, pos.longitude);
  } catch (_) {
    throw const LocationFailure('تعذّر تحديد الموقع الآن. حاول في مكان مكشوف أو اكتفِ بالعنوان المكتوب.');
  }
}
