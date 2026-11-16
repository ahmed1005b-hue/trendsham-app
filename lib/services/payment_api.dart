import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'api_exception.dart';

class PaymentApi {
  PaymentApi([ApiClient? api]) : _api = api ?? ApiClient();
  final ApiClient _api;

  /// GET /payments/config — هل الدفع الإلكتروني وحفظ البطاقات مفعّلان؟
  Future<PaymentConfig> config() async {
    final data = await _api.get('/payments/config');
    if (data is! Map) return const PaymentConfig();
    return PaymentConfig.fromJson(Map<String, dynamic>.from(data));
  }

  /// POST /payments/start  {order_id, card_id?}  (server computes amount)
  Future<PaymentStartResult> startPayment(int orderId, {int? cardId}) async {
    final data = await _api.post('/payments/start', body: {
      'order_id': orderId,
      if (cardId != null) 'card_id': cardId,
    });
    if (data is! Map) throw const ApiException('استجابة بدء الدفع غير صالحة.');
    return PaymentStartResult.fromJson(Map<String, dynamic>.from(data));
  }

  /// GET /orders/{id}/payment-status  — source of truth
  Future<PaymentStatusResult> getPaymentStatus(int orderId) async {
    final data = await _api.get('/orders/$orderId/payment-status');
    if (data is! Map) throw const ApiException('استجابة حالة الدفع غير صالحة.');
    return PaymentStatusResult.fromJson(Map<String, dynamic>.from(data));
  }

  /// Opens hosted checkout URL. Never collects card data in-app.
  Future<bool> openCheckout(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Poll status every 3s up to [attempts] times. Trusts server only.
  Future<PaymentStatusResult> pollStatus(int orderId,
      {int attempts = 20,
      Duration interval = const Duration(seconds: 3)}) async {
    PaymentStatusResult? last;
    for (var i = 0; i < attempts; i++) {
      last = await getPaymentStatus(orderId);
      if (last.paid || last.failed) return last;
      if (i < attempts - 1) await Future.delayed(interval);
    }
    return last ?? PaymentStatusResult(status: 'pending', paid: false);
  }

  // ------------------------------------------------------------ البطاقات المحفوظة

  Future<SavedCardsResult> cards() async {
    final data = await _api.get('/cards');
    if (data is! Map) return const SavedCardsResult(enabled: false, cards: []);
    final list = data['data'] is List ? data['data'] as List : const [];
    return SavedCardsResult(
      enabled: data['enabled'] == true,
      cards: list
          .whereType<Map>()
          .map((c) => SavedCard.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  /// يعيد رابط صفحة البنك لإدخال البطاقة (تُفتح في المتصفح) + المرجع لمتابعة الحالة.
  Future<({String reference, String url})> startAddCard() async {
    final data = await _api.post('/cards');
    if (data is! Map || data['url'] == null) {
      throw const ApiException('تعذّر فتح صفحة البنك.');
    }
    return (
      reference: data['reference'].toString(),
      url: data['url'].toString()
    );
  }

  /// pending | active | failed
  Future<String> cardStatus(String reference) async {
    final data = await _api.get('/cards/status/$reference');
    return data is Map ? (data['status'] ?? 'pending').toString() : 'pending';
  }

  Future<String> pollCardStatus(String reference,
      {int attempts = 20,
      Duration interval = const Duration(seconds: 3)}) async {
    var status = 'pending';
    for (var i = 0; i < attempts; i++) {
      status = await cardStatus(reference);
      if (status != 'pending') return status;
      if (i < attempts - 1) await Future.delayed(interval);
    }
    return status;
  }

  Future<void> setDefaultCard(int id) => _api.post('/cards/$id/default');

  Future<void> deleteCard(int id) => _api.delete('/cards/$id');
}

class PaymentConfig {
  const PaymentConfig(
      {this.onlineEnabled = false, this.savedCardsEnabled = false});
  final bool onlineEnabled;
  final bool savedCardsEnabled;

  factory PaymentConfig.fromJson(Map<String, dynamic> j) => PaymentConfig(
        onlineEnabled: j['online_enabled'] == true,
        savedCardsEnabled: j['saved_cards_enabled'] == true,
      );
}

class SavedCardsResult {
  const SavedCardsResult({required this.enabled, required this.cards});
  final bool enabled;
  final List<SavedCard> cards;
}

/// بطاقة محفوظة: لا يوجد رقم البطاقة إطلاقاً — آخر 4 أرقام فقط.
class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.brandLabel,
    required this.last4,
    this.expiry,
    this.holderName,
    this.isDefault = false,
    this.isExpired = false,
  });

  final int id;
  final String brand;
  final String brandLabel;
  final String last4;
  final String? expiry;
  final String? holderName;
  final bool isDefault;
  final bool isExpired;

  String get masked => '•••• $last4';

  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
        id: (j['id'] as num).toInt(),
        brand: (j['brand'] ?? '').toString(),
        brandLabel: (j['brand_label'] ?? 'بطاقة').toString(),
        last4: (j['last4'] ?? '----').toString(),
        expiry: j['expiry']?.toString(),
        holderName: j['holder_name']?.toString(),
        isDefault: j['is_default'] == true,
        isExpired: j['is_expired'] == true,
      );
}

class PaymentStartResult {
  PaymentStartResult(
      {required this.reference,
      required this.type,
      this.url,
      this.message,
      this.paid = false});
  final String reference;
  final String type; // redirect | manual | paid | failed
  final String? url;
  final String? message;
  final bool paid;

  factory PaymentStartResult.fromJson(Map<String, dynamic> j) =>
      PaymentStartResult(
        reference: (j['reference'] ?? '').toString(),
        type: (j['type'] ?? 'manual').toString(),
        url: j['url']?.toString(),
        message: j['message']?.toString(),
        paid: j['paid'] == true,
      );
}

class PaymentStatusResult {
  PaymentStatusResult({required this.status, required this.paid});
  final String status; // none|pending|paid|failed|cancelled|refunded
  final bool paid;
  bool get failed => status == 'failed' || status == 'cancelled';
  bool get pending => status == 'none' || status == 'pending';

  factory PaymentStatusResult.fromJson(Map<String, dynamic> j) =>
      PaymentStatusResult(
        status: (j['status'] ?? 'none').toString(),
        paid: j['paid'] == true,
      );
}
