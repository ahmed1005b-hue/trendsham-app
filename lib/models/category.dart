import '../l10n/category_translations.dart';

class Category {
  final int id;
  final String slug;
  final String name; // canonical/source name (Arabic)
  final String? translatedName;
  final String? nameEn;
  final String? nameTr;
  final String? image;
  final List<Category> children;

  Category({
    required this.id,
    required this.slug,
    required this.name,
    this.translatedName,
    this.nameEn,
    this.nameTr,
    this.image,
    this.children = const [],
  });

  String localizedName([String? languageCode]) {
    final code = (languageCode ?? 'ar').toLowerCase();
    if (code != 'ar' && translatedName != null && translatedName!.isNotEmpty) return translatedName!;
    if (code == 'en' && nameEn != null && nameEn!.isNotEmpty) return nameEn!;
    if (code == 'tr' && nameTr != null && nameTr!.isNotEmpty) return nameTr!;
    return CategoryTranslations.translate(name);
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      slug: json['slug'],
      name: json['name'],
      translatedName: json['translated_name']?.toString(),
      nameEn: json['name_en']?.toString(),
      nameTr: json['name_tr']?.toString(),
      image: json['image'],
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => Category.fromJson(c))
          .toList(),
    );
  }
}
