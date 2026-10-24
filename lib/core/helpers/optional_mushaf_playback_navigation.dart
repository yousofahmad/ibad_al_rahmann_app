import 'mushaf_pagination.dart';

/// Optional-format navigation only. Builtin playback keeps its original branch.
abstract final class OptionalMushafPlaybackNavigation {
  /// [oneBasedWordPosition] already matches QuranWord.position; never add one.
  static int? targetPageIndex({
    required int surah,
    required int ayah,
    required int? currentPageIndex,
    required int? oneBasedWordPosition,
    required bool followWords,
    int? pageCount,
    int Function(int, int)? pageForAyah,
    int? Function(int, int, int)? pageForWord,
    bool Function(int, int, int)? pageContainsAyah,
  }) {
    final count = pageCount ?? MushafPagination.pageCount;
    final resolveAyah = pageForAyah ?? MushafPagination.pageForAyah;
    final resolveWord = pageForWord ?? MushafPagination.pageForWord;
    final containsAyah = pageContainsAyah ?? MushafPagination.pageContainsAyah;
    final position = oneBasedWordPosition;
    if (followWords && position != null && position > 0) {
      final wordPage = resolveWord(surah, ayah, position);
      if (wordPage != null && wordPage >= 1 && wordPage <= count) {
        return wordPage - 1;
      }
    }
    // A null/unknown timing index is a separator, not a request to jump back
    // from the second part of an ayah to its first page.
    if (currentPageIndex != null &&
        currentPageIndex >= 0 &&
        currentPageIndex < count &&
        containsAyah(currentPageIndex + 1, surah, ayah)) {
      return currentPageIndex;
    }
    final ayahPage = resolveAyah(surah, ayah);
    return ayahPage >= 1 && ayahPage <= count ? ayahPage - 1 : null;
  }
}
