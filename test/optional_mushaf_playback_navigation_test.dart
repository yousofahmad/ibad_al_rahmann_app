import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/optional_mushaf_playback_navigation.dart';

void main() {
  group('OptionalMushafPlaybackNavigation', () {
    int? target({
      required int? currentPage,
      required int? wordPosition,
      bool followWords = true,
    }) => OptionalMushafPlaybackNavigation.targetPageIndex(
      surah: 1,
      ayah: 5,
      currentPageIndex: currentPage,
      oneBasedWordPosition: wordPosition,
      followWords: followWords,
      pageCount: 10,
      pageForAyah: (_, _) => 4,
      pageForWord: (_, _, word) => word <= 3 ? 4 : 5,
      pageContainsAyah: (page, _, _) => page == 4 || page == 5,
    );

    test('uses audio word position as the one-based sidecar key', () {
      expect(target(currentPage: 3, wordPosition: 3), 3);
      expect(target(currentPage: 3, wordPosition: 4), 4);
      expect(target(currentPage: 4, wordPosition: 5), 4);
    });

    test('does not jump to the first split page during a timing gap', () {
      expect(target(currentPage: 4, wordPosition: null), 4);
    });

    test('keeps verse navigation when word following is disabled', () {
      expect(target(currentPage: 3, wordPosition: 4, followWords: false), 3);
    });

    test('falls back to the ayah start when the current page has no ayah', () {
      expect(target(currentPage: 7, wordPosition: null), 3);
    });

    test('rejects sidecar page values outside the format page range', () {
      final result = OptionalMushafPlaybackNavigation.targetPageIndex(
        surah: 1,
        ayah: 5,
        currentPageIndex: null,
        oneBasedWordPosition: 1,
        followWords: true,
        pageCount: 10,
        pageForAyah: (_, _) => 4,
        pageForWord: (_, _, _) => 0,
        pageContainsAyah: (_, _, _) => false,
      );
      expect(result, 3);
    });
  });
}
