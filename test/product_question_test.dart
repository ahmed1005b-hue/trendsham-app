import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product_question.dart';

void main() {
  group('ProductQuestion parsing', () {
    test('parses the API question payload with nested answers', () {
      final question = ProductQuestion.fromJson({
        'id': 7,
        'question': 'هل يتوفر مقاس L؟',
        'asker_name': 'سارة',
        'helpful_count': 3,
        'is_helpful': true,
        'is_answered': true,
        'can_delete': false,
        'created_at': '2024-06-01T12:30:00.000Z',
        'answers': [
          {
            'id': 21,
            'answer': 'نعم، متوفر M و L',
            'is_seller_answer': true,
            'author_name': 'متجر الأناقة',
            'created_at': '2024-06-01T13:00:00.000Z',
          },
        ],
      });

      expect(question.id, 7);
      expect(question.question, 'هل يتوفر مقاس L؟');
      expect(question.askerName, 'سارة');
      expect(question.helpfulCount, 3);
      expect(question.isHelpful, isTrue);
      expect(question.isAnswered, isTrue);
      expect(question.canDelete, isFalse);
      expect(question.createdAt, isNotNull);
      expect(question.answers, hasLength(1));

      final answer = question.answers.first;
      expect(answer.id, 21);
      expect(answer.answer, 'نعم، متوفر M و L');
      expect(answer.isSellerAnswer, isTrue);
      expect(answer.authorName, 'متجر الأناقة');
    });

    test('applies safe defaults for missing or null fields', () {
      final question = ProductQuestion.fromJson({
        'id': 8,
        'question': 'ما مدة الشحن؟',
      });

      expect(question.id, 8);
      expect(question.askerName, '');
      expect(question.helpfulCount, 0);
      expect(question.isHelpful, isFalse);
      expect(question.isAnswered, isFalse);
      expect(question.canDelete, isFalse);
      expect(question.createdAt, isNull);
      expect(question.answers, isEmpty);
    });
  });

  group('QuestionHelpfulResult parsing', () {
    test('reads the toggle helpful response', () {
      final result = QuestionHelpfulResult.fromJson({
        'is_helpful': true,
        'helpful_count': 4,
      });

      expect(result.isHelpful, isTrue);
      expect(result.helpfulCount, 4);
    });
  });
}
