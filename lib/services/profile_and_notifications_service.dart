import '../models/notification.dart';
import '../models/product.dart';
import '../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class FavoriteService {
  final ApiClient _api = ApiClient();

  Future<List<Product>> list() async {
    final data = await _api.get('/favorites');
    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<bool> toggle(int productId) async {
    final data = await _api.post('/favorites/$productId/toggle');
    return data['favorited'] ?? false;
  }
}

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<AppNotification>> list() async {
    final data = await _api.get('/notifications');
    return (data['data'] as List)
        .map((n) => AppNotification.fromJson(n))
        .toList();
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return data['count'] ?? 0;
  }

  Future<void> markRead(int id) async {
    await _api.post('/notifications/$id/read');
  }
}

class ProfileService {
  final ApiClient _api = ApiClient();

  Future<AppUser> show() async {
    final data = await _api.get('/profile');
    return AppUser.fromJson(data['data'] ?? data);
  }
  Future<AppUser> update({
    required String firstName,
    required String lastName,
    String? address,
    required String email,
    String? countryCode,
    String? nationalNumber,
    String? birthDate,
    String? city,
    String? gender,
    XFile? avatarImage,
  }) async {
    final fields = <String, String>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      '_method': 'PUT',
    };
    void put(String key, String? value) {
      if (value != null) fields[key] = value;
    }
    put('address', address);
    put('country_code', countryCode);
    put('national_number', nationalNumber);
    put('birth_date', birthDate);
    put('city', city);
    put('gender', gender);
    if (avatarImage != null) {
      final data = await _api.postMultipart(
        '/profile',
        fields: fields,
        images: [avatarImage],
        imageParamName: 'avatar',
      );
      return AppUser.fromJson(data['data'] ?? data);
    }
    final data = await _api.put('/profile', body: fields..remove('_method'));
    return AppUser.fromJson(data['data'] ?? data);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.put('/profile/password', body: {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
