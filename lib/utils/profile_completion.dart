import '../models/user.dart';

/// بند في نسبة إكمال الملف الشخصي.
class CompletionItem {
  final String key;
  final String label;
  final bool done;
  const CompletionItem(this.key, this.label, this.done);
}

/// نسبة إكمال حقيقية من بيانات المستخدم (بدل 70% الثابتة سابقاً).
/// عنوان الشحن المعتمد جزء منها لأن البائع يحتاجه لإرسال الشحنة.
class ProfileCompletion {
  final List<CompletionItem> items;
  const ProfileCompletion(this.items);

  factory ProfileCompletion.of(AppUser user) {
    bool filled(String? v) => v != null && v.trim().isNotEmpty;
    return ProfileCompletion([
      CompletionItem('avatar', 'الصورة الشخصية', user.avatarUrl != null),
      CompletionItem('name', 'الاسم واللقب',
          filled(user.firstName) && filled(user.lastName)),
      CompletionItem('email', 'البريد الإلكتروني', filled(user.email)),
      CompletionItem('birth_date', 'تاريخ الميلاد', filled(user.birthDate)),
      CompletionItem('gender', 'الجنس', filled(user.gender)),
      CompletionItem('address', 'عنوان الشحن', user.defaultAddress != null),
    ]);
  }

  int get done => items.where((i) => i.done).length;

  /// 0..1
  double get ratio => items.isEmpty ? 1 : done / items.length;

  /// 0..100 مقرّبة
  int get percent => (ratio * 100).round();

  bool get isComplete => done == items.length;

  List<CompletionItem> get missing => items.where((i) => !i.done).toList();

  /// الناقص الوحيد هو عنوان الشحن؟ (يُفتح عندها شاشة العناوين مباشرة)
  bool get onlyAddressMissing =>
      missing.length == 1 && missing.first.key == 'address';
}
