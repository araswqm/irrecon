import '../../core/constants.dart';

/// Provides Levenshtein distance-based fuzzy string matching.
class FuzzyMatcher {
  /// Computes the Levenshtein distance between two strings.
  static int levenshteinDistance(String a, String b) {
    final aLen = a.length;
    final bLen = b.length;

    final matrix = List.generate(aLen + 1, (_) => List.filled(bLen + 1, 0));

    for (var i = 0; i <= aLen; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= bLen; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= aLen; i++) {
      for (var j = 1; j <= bLen; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[aLen][bLen];
  }

  /// Returns a normalized similarity score between 0.0 and 1.0.
  /// 1.0 means exact match, 0.0 means completely different.
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = levenshteinDistance(a, b).toDouble();
    final maxLen = a.length > b.length ? a.length.toDouble() : b.length.toDouble();

    return 1.0 - (distance / maxLen);
  }

  /// Case-insensitive similarity.
  static double similarityIgnoreCase(String a, String b) {
    return similarity(a.toLowerCase(), b.toLowerCase());
  }

  /// Checks if two strings match above the given [threshold].
  static bool isMatch(String a, String b,
      [double threshold = AppConstants.matchThreshold]) {
    return similarityIgnoreCase(a, b) >= threshold;
  }

  /// Finds the best match for [query] among [candidates].
  /// Returns the best candidate and its score, or null if none pass the threshold.
  static (String match, double score)? bestMatch(
    String query,
    Iterable<String> candidates, {
    double threshold = AppConstants.matchThreshold,
  }) {
    String? best;
    var bestScore = 0.0;

    for (final candidate in candidates) {
      final score = similarityIgnoreCase(query, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best == null || bestScore < threshold) return null;
    return (best, bestScore);
  }

  /// Normalizes a brand name for indexing and comparison.
  /// Strips non-alphanumeric characters and lowercases.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
