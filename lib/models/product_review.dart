class ProductReview {
  final int id;
  final int rating;
  final String? comment;
  final String customerName;
  final bool verifiedPurchase;
  final DateTime? createdAt;

  const ProductReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.customerName,
    required this.verifiedPurchase,
    this.createdAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      verifiedPurchase: json['verified_purchase'] == true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
