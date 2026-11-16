class ProductQuestionAnswer {
  final int id;
  final String answer;
  final bool isSellerAnswer;
  final String authorName;
  final DateTime? createdAt;

  const ProductQuestionAnswer({
    required this.id,
    required this.answer,
    required this.isSellerAnswer,
    required this.authorName,
    this.createdAt,
  });

  factory ProductQuestionAnswer.fromJson(Map<String, dynamic> json) {
    return ProductQuestionAnswer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      answer: json['answer']?.toString() ?? '',
      isSellerAnswer: json['is_seller_answer'] == true,
      authorName: json['author_name']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class ProductQuestion {
  final int id;
  final String question;
  final String askerName;
  final int helpfulCount;
  final bool isHelpful;
  final bool isAnswered;
  final bool canDelete;
  final DateTime? createdAt;
  final List<ProductQuestionAnswer> answers;

  const ProductQuestion({
    required this.id,
    required this.question,
    required this.askerName,
    required this.helpfulCount,
    required this.isHelpful,
    required this.isAnswered,
    required this.canDelete,
    this.createdAt,
    this.answers = const [],
  });

  factory ProductQuestion.fromJson(Map<String, dynamic> json) {
    return ProductQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question']?.toString() ?? '',
      askerName: json['asker_name']?.toString() ?? '',
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      isHelpful: json['is_helpful'] == true,
      isAnswered: json['is_answered'] == true,
      canDelete: json['can_delete'] == true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      answers: (json['answers'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((a) =>
              ProductQuestionAnswer.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }
}

/// نتيجة التصويت "مفيد" القادمة من الـ API.
class QuestionHelpfulResult {
  final bool isHelpful;
  final int helpfulCount;

  const QuestionHelpfulResult({
    required this.isHelpful,
    required this.helpfulCount,
  });

  factory QuestionHelpfulResult.fromJson(Map<String, dynamic> json) {
    return QuestionHelpfulResult(
      isHelpful: json['is_helpful'] == true,
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
    );
  }
}


