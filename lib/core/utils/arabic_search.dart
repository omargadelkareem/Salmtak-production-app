/// Shared Arabic search helpers used across Salamtak.
///
/// Normalizes common Arabic spelling variants so searches such as
/// "اسيوط" match "أسيوط" and "احمد" match "أحمد".
String normalizeArabicSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ـ', '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool arabicSearchContains(String source, String query) {
  final normalizedQuery = normalizeArabicSearch(query);
  if (normalizedQuery.isEmpty) return true;
  return normalizeArabicSearch(source).contains(normalizedQuery);
}

bool arabicSearchMatchesAny(Iterable<dynamic> values, String query) {
  final normalizedQuery = normalizeArabicSearch(query);
  if (normalizedQuery.isEmpty) return true;

  for (final value in values) {
    if (normalizeArabicSearch(value?.toString() ?? '')
        .contains(normalizedQuery)) {
      return true;
    }
  }
  return false;
}
