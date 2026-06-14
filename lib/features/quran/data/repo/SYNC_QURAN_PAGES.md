## Quran Navigation and Synchronization

This document describes how the app synchronizes navigation among the Quran page viewers and lists, along with the APIs for page, surah, and verse navigation and the highlighting behavior.

### Overview

- **Three synchronized controllers**:
  - **minQuranController**: main Quran pages `PageView` (mini/primary view)
  - **pagesController**: compact pages list `PageView`
  - **surahsController**: surah list `PageView`
- **Bidirectional sync**:
  - Scrolling the Quran pages updates the pages list, and vice versa.
  - Scrolling the pages list updates the main Quran pages.
  - Surah changes keep the surah list aligned with the current page.
- **Feedback loop prevention**: guard flags are set during programmatic animations and reset in `finally` blocks.

### Files

- `lib/features/quran/data/repo/quran_repo.dart`
- `lib/features/quran/bloc/quran/quran_cubit.dart`
- `lib/features/quran/ui/widgets/min_quran_mobile.dart`
- `lib/features/quran/ui/widgets/full_quran_mobile.dart`
- `lib/features/quran/ui/widgets/quran_pages_list.dart`
- `lib/features/quran/ui/layouts/*_surah_verses_widget.dart`

### Public API (Cubit)

- `Future<void> navigateToPage(int pageIndex, {String? highligthedVerse})`
- `Future<void> navigateToSurah(int surahNumber)`
- `Future<void> navigateToVerse({required int surahNumber, required int verseNumber})`
- `Future<void> onQuranPageChanged(int pageIndex)`
- `Future<void> onPagesListChanged(int pageIndex)`
- `Future<void> onSurahListChanged(int surahIndex)`
- `void clearHighlightedVerse()`

### Guard Strategy

Three boolean guards prevent re-entrant updates during programmatic animations:

```dart
bool _suppressQuranChanged = false;
bool _suppressPagesChanged = false;
bool _suppressSurahsChanged = false;
```

When animating a controller in response to another, set the corresponding guards before the animation and clear them in a `finally` block. This ensures guards reset even if animations are interrupted.

### Navigation Logic (Repo)

- Page navigation (0-based index):
```dart
Future<void> navigateToPage(int pageIndex) async {
  _suppressQuranChanged = true;
  try {
    await minQuranController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.linearToEaseOut,
    );
  } finally {
    _suppressQuranChanged = false;
  }
}
```

- Surah navigation (syncs pages and surah lists):
```dart
Future<void> navigateToSurah(int surahNumber) async {
  final int page = getSurahPages(surahNumber).first - 1;
  _suppressQuranChanged = true;
  _suppressPagesChanged = true;
  _suppressSurahsChanged = true;
  try {
    await Future.wait([
      minQuranController.animateToPage(page, duration: const Duration(seconds: 1), curve: Curves.linearToEaseOut),
      pagesController.animateToPage(page, duration: const Duration(seconds: 1), curve: Curves.linearToEaseOut),
      surahsController.animateToPage(surahNumber - 1, duration: const Duration(seconds: 1), curve: Curves.linearToEaseOut),
    ]);
  } finally {
    _suppressQuranChanged = false;
    _suppressPagesChanged = false;
    _suppressSurahsChanged = false;
  }
}
```

- Verse navigation (new): computes the verse page and synchronizes all controllers:
```dart
Future<void> navigateToVerse(int surahNumber, int verseNumber) async {
  final int page = getPageNumber(surahNumber, verseNumber) - 1;
  _suppressQuranChanged = true;
  _suppressPagesChanged = true;
  _suppressSurahsChanged = true;
  try {
    await Future.wait([
      minQuranController.animateToPage(page, duration: const Duration(milliseconds: 500), curve: Curves.linearToEaseOut),
      pagesController.animateToPage(page, duration: const Duration(milliseconds: 500), curve: Curves.linearToEaseOut),
      surahsController.animateToPage(surahNumber - 1, duration: const Duration(milliseconds: 500), curve: Curves.linearToEaseOut),
    ]);
  } finally {
    _suppressQuranChanged = false;
    _suppressPagesChanged = false;
    _suppressSurahsChanged = false;
  }
}
```

### Change Handlers

- Quran pages changed → update pages list and surah list when needed:
```dart
Future<void> onQuranPageChanged(int pageIndex) async {
  if (_suppressQuranChanged) return;
  final int currentPages = pagesController.hasClients
      ? (pagesController.page?.round() ?? pagesController.initialPage)
      : pagesController.initialPage;
  final List<Future<void>> pending = [];
  if (currentPages != pageIndex) {
    _suppressPagesChanged = true;
    pending.add(pagesController.animateToPage(pageIndex, duration: const Duration(milliseconds: 300), curve: Curves.linearToEaseOut));
  }
  pending.add(_updateSurahsControllerIfChanged(pageIndex + 1));
  try {
    await Future.wait(pending);
  } finally {
    _suppressPagesChanged = false;
  }
}
```

- Pages list changed → update main Quran pages (and surah if changed):
```dart
Future<void> onPagesListChanged(int pageIndex) async {
  if (_suppressPagesChanged) return;
  _suppressQuranChanged = true;
  try {
    await Future.wait([
      minQuranController.animateToPage(pageIndex, duration: const Duration(milliseconds: 400), curve: Curves.linearToEaseOut),
      _updateSurahsControllerIfChanged(pageIndex + 1),
    ]);
  } finally {
    _suppressQuranChanged = false;
  }
}
```

- Surah list changed → call `navigateToSurah(surahIndex + 1)` when not suppressed.

### Verse Highlighting

- The cubit exposes a transient `highligthedVerse` string used by verse widgets to visually highlight the matching verse on the current page.
- When navigating:
  - `navigateToPage(..., highligthedVerse: verseText)` can set a highlight for page jumps.
  - `navigateToVerse(surahNumber, verseNumber)` computes the QCF text for the verse, removes spaces, inserts a thin space `\u200A` after the first character, and emits it.
- Highlight lifecycle:
  - Verse widgets receive `highlightedVerse` and briefly highlight it (auto-clear after ~2 seconds unless the user long-presses a verse).
  - On user scroll (page change), the cubit calls `clearHighlightedVerse()` to remove transient highlights.

### Widget Wiring

- Main Quran page views use `minQuranController` and call `onQuranPageChanged` with zero-based indices.
- `quran_pages_list.dart` uses `pagesController` and calls `onPagesListChanged` with zero-based indices.
- Verse-rendering widgets (`MobileSurahVersesWidget`, `TabletSurahVersesWidget`) accept an optional `highlightedVerse` and internally normalize text to match and highlight.
- Layout wrappers (e.g., `min_page_rich_text_mobile.dart`, `min_page_rich_text_tablet.dart`) pass `state.highligthedVerse` into the verse widgets.

### Testing Scenarios

- Scroll Quran pages to N → pages list updates to N; surah list updates if crossing into a new surah.
- Scroll pages list to M → Quran pages update to M; surah list updates if needed.
- Call `navigateToSurah(S)` → all controllers land on the surah's first page and remain synchronized.
- Call `navigateToVerse(S, V)` → controllers land on the verse's page; the verse is briefly highlighted.

### Future Improvements

- Debounce rapid scroll updates if performance becomes an issue.
- Consider using `jumpToPage` for instant sync in compact modes.
- Persist last-read page and restore on launch.
- Provide an option to keep highlights until explicitly cleared.