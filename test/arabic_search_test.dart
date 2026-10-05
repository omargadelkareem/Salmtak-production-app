import 'package:flutter_test/flutter_test.dart';
import 'package:salmtak/core/utils/arabic_search.dart';

void main() {
  group('normalizeArabicSearch', () {
    test('normalizes hamza variants', () {
      expect(normalizeArabicSearch('أسيوط'), 'اسيوط');
      expect(normalizeArabicSearch('إسلام'), 'اسلام');
      expect(normalizeArabicSearch('آدم'), 'ادم');
    });

    test('normalizes ya, ta marbuta and diacritics', () {
      expect(normalizeArabicSearch('عيادة'), 'عياده');
      expect(normalizeArabicSearch('على'), 'علي');
      expect(normalizeArabicSearch('أَحْمَد'), 'احمد');
    });

    test('matches doctor, specialty and location text', () {
      expect(arabicSearchContains('د. أحمد محمد', 'احمد'), isTrue);
      expect(arabicSearchContains('أسنان', 'اسنان'), isTrue);
      expect(arabicSearchContains('أسيوط', 'اسيوط'), isTrue);
      expect(
        arabicSearchMatchesAny(
          ['د. أحمد محمد', 'أنف وأذن وحنجرة', 'أسيوط'],
          'انف',
        ),
        isTrue,
      );
    });
  });
}
