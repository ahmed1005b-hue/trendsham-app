import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoreVisitorTokenStorage {
  static const _key = 'storefront_visitor_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
      return existing;
    }

    final random = Random.secure();
    final token = List<int>.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _key, value: token);
    return token;
  }

  Future<void> save(String token) async {
    if (RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      await _storage.write(key: _key, value: token);
    }
  }
}
