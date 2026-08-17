import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/data/quran_word.dart';
import 'package:ibad_al_rahmann/features/quran/data/db_helper.dart'; // Ensure db helper import
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:quran/quran.dart';

part 'quran_state.dart';

class QuranCubit extends Cubit<QuranState> {
  final bool isWirdMode;
  final bool isKahfMode;
  final String? khatmaId;
  final int? wirdStartPage;
  final int? targetEndPage;
  final int? wirdIndex;
  final Map<int, List<QuranWord>> pageCache = {};

  /// Keys for RepaintBoundary per page – used for HD page capture.
  /// Categorized by context (e.g. 'mushaf', 'wird') to avoid GlobalKey collisions.
  final Map<String, GlobalKey> pageKeys = {};

  /// Returns (or creates) a GlobalKey for the given [pageNumber] and [contextPrefix].
  GlobalKey getPageKey(int pageNumber, {String contextPrefix = 'mushaf'}) {
    final key = '${contextPrefix}_$pageNumber';
    return pageKeys.putIfAbsent(key, () => GlobalKey());
  }

  QuranCubit(
    this._repo, {
    this.isWirdMode = false,
    this.isKahfMode = false,
    this.khatmaId,
    this.wirdStartPage,
    this.targetEndPage,
    this.wirdIndex,
  }) : super(
         QuranState(
           layout: QuranLayout.min,
           juzNumber: 1,
           isWirdMode: isWirdMode,
           isKahfMode: isKahfMode,
           khatmaId: khatmaId,
           wirdStartPage: wirdStartPage,
           targetEndPage: targetEndPage,
           wirdIndex: wirdIndex,
         ),
       ) {
    _initializeCache();
  }

  int getCurrentJuzNumber({
    required int surahNumber,
    required int verseNumber,
  }) {
    return getJuzNumber(surahNumber, verseNumber);
  }

  final QuranRepo _repo;

  static const String _lastPageKey = 'last_quran_page';
  static const String _lastWirdPageKey = 'last_wird_page';
  static const String _lastLayoutKey = 'last_quran_layout';
  static const String _quranColorKey = 'quran_paper_color';
  static const String _wirdColorKey = 'wird_paper_color';
  static const String _kahfColorKey = 'kahf_paper_color';
  static const String _quranMarginKey = 'quran_page_margin';

  /// Initialize cache and load the last page
  Future<void> _initializeCache() async {
    await getIt<CacheService>().init();
    await _loadLastPage();
  }

  /// Load the last page from cache and set it as initial page
  Future<void> _loadLastPage() async {
    int? lastPage;
    
    if (isKahfMode) {
      lastPage = await DailyTrackerService.getKahfProgress();
    } else if (isWirdMode && khatmaId != null && wirdIndex != null) {
      final int relative = getIt<CacheService>().getInt('wird_${khatmaId}_${wirdIndex}_current_page') ?? 0;
      lastPage = (wirdStartPage ?? 1) - 1 + relative;
    } else if (isWirdMode) {
      lastPage = getIt<CacheService>().getInt(_lastWirdPageKey);
    } else {
      lastPage = getIt<CacheService>().getInt(_lastPageKey);
    }

    final String? lastLayoutString = await getIt<CacheService>().getString(
      _lastLayoutKey,
    );
    // Load saved paper colors from cache (-1 means not set)
    final int? quranColorVal = getIt<CacheService>().getInt(_quranColorKey);
    final int? wirdColorVal = getIt<CacheService>().getInt(_wirdColorKey);
    final int? kahfColorVal = getIt<CacheService>().getInt(_kahfColorKey);
    
    final double savedMargin =
        (getIt<CacheService>().getDouble(_quranMarginKey) ?? 16.0).clamp(
          0.0,
          40.0,
        );
    final Color? qColorSaved = (quranColorVal != null && quranColorVal != -1)
        ? Color(quranColorVal)
        : null;
    final Color? wColorSaved = (wirdColorVal != null && wirdColorVal != -1)
        ? Color(wirdColorVal)
        : null;
    final Color? kColorSaved = (kahfColorVal != null && kahfColorVal != -1)
        ? Color(kahfColorVal)
        : null;

    // The Mushaf has 'special treatment' and does not strictly follow the app's 
    // global theme or system brightness for its paper background. 
    // We default to a traditional cream color (0xFFFFF9E5).
    const Color fallbackColor = Color(0xFFFFF9E5);

    final Color qColor = qColorSaved ?? fallbackColor;
    final Color wColor = wColorSaved ?? fallbackColor;
    final Color kColor = kColorSaved ?? fallbackColor;

    final bool initialIsWird = isWirdMode || isKahfMode;
    final QuranLayout initialLayout = initialIsWird ? QuranLayout.full : (lastLayoutString == 'full'
          ? QuranLayout.full
          : QuranLayout.min);

    if (lastPage != null) {
      final int pageNumber = lastPage + 1;
      final pageData = getPageData(pageNumber);
      int juzNum = getCurrentJuzNumber(
        surahNumber: pageData[0]['surah'],
        verseNumber: pageData[0]['start'],
      );
      emit(
        state.copyWith(
          layout: initialLayout,
          juzNumber: juzNum,
          currentPage: lastPage,
          quranPaperColor: qColor,
          wirdPaperColor: wColor,
          kahfPaperColor: kColor,
          quranPageMargin: savedMargin,
        ),
      );
    } else {
      // No saved page — still apply color defaults so menus are correct.
      emit(
        state.copyWith(
          layout: initialLayout,
          quranPaperColor: qColor,
          wirdPaperColor: wColor,
          kahfPaperColor: kColor,
          quranPageMargin: savedMargin,
        ),
      );
    }
  }

  /// Save the current page to cache
  Future<void> _saveCurrentPage(int pageIndex) async {
    if (state.isKahfMode) {
      await DailyTrackerService.saveKahfProgress(pageIndex);
      // Kahf ends on page 304 (index 303)
      if (pageIndex >= 303) {
        await DailyTrackerService.markKahfDone();
      }
      return;
    }

    if (state.isWirdMode && state.khatmaId != null && state.wirdIndex != null) {
      final cache = getIt<CacheService>();
      final int startPage = state.wirdStartPage ?? 1;
      final int relativeIndex = (pageIndex - (startPage - 1)).clamp(0, 604);

      await cache.setInt(
        'wird_${state.khatmaId}_${state.wirdIndex}_current_page',
        relativeIndex,
      );
      // Also update the global last_wird_page for fallback
      await cache.setInt(_lastWirdPageKey, pageIndex);
      return;
    }

    const key = _lastPageKey;
    await getIt<CacheService>().setInt(key, pageIndex);
  }

  /// Save the current layout to cache
  Future<void> _saveCurrentLayout(QuranLayout layout) async {
    await getIt<CacheService>().setString(_lastLayoutKey, layout.name);
  }

  PageController get pagesController => _repo.pagesController;
  PageController get surahsController => _repo.surahsController;
  PageController get minQuranController => _repo.minQuranController;
  PageController get fullQuranController => _repo.fullQuranController;

  int get currentSurahIndex =>
      surahsController.hasClients ? (surahsController.page?.round() ?? 0) : 0;

  // Called when Pages list PageView changes (zero-based index)
  void onPagesListChanged(int pageIndex) async {
    await _repo.onPagesListChanged(pageIndex);
  }

  // Jumps immediate without animation for performance optimization
  void jumpToPage(int pageIndex) async {
    await _repo.jumpToPage(pageIndex);
  }

  // Navigate Quran main pager to the given zero-based page index
  Timer? _highlightTimer;

  Future<void> navigateToPage(int pageIndex, {String? highligthedVerse}) async {
    await _repo.navigateToPage(pageIndex);

    if (highligthedVerse != null) {
      // Cancel any previous auto-clear timer
      _highlightTimer?.cancel();

      emit(
        state.copyWith(
          highligthedVerse:
              '${highligthedVerse.substring(0, 1)}\u200A${highligthedVerse.substring(1)}',
        ),
      );

      // Auto-clear highlight after 10 seconds
      _highlightTimer = Timer(const Duration(seconds: 10), () {
        clearHighlightedVerse();
      });
    }
  }

  // Clear the transient highlighted verse (e.g., after navigation/scroll)
  void clearHighlightedVerse() {
    _highlightTimer?.cancel();
    if (state.highligthedVerse != null || state.highlightedSurah != null) {
      emit(state.copyWith(clearHighligthedVerse: true));
    }
  }

  Timer? _pageChangeDebounce;

  // Called when Quran PageView page changes (zero-based index)
  Future<void> onQuranPageChanged(int pageIndex) async {
    // Immediate UI updates - must keep these fast
    await _repo.onQuranPageChanged(pageIndex);

    final pageNumber = pageIndex + 1;
    final pageData = getPageData(pageNumber);
    int juzNum = getCurrentJuzNumber(
      surahNumber: pageData[0]['surah'],
      verseNumber: pageData[0]['start'],
    );

    AppLogger.log('Quran', 'Page changed to $pageNumber (Juz $juzNum)');
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageIndex));
    clearHighlightedVerse();

    // Stop auto scrolling if manually changed or if new page requires pausing
    if (!state.isAutoScrolling) {
      // if it wasn't auto scrolling, nothing to do here.
    } else {
      // Actually let's stop auto scrolling when user manually swipes
      // If the timer is what triggered it, it's fine. But wait, we can't tell easily.
      // It's better to stop auto scrolling inside the GestureDetector in the UI.
    }

    // Debounce heavy background tasks (I/O) to avoid stuttering during fast scrolls
    _pageChangeDebounce?.cancel();
    _pageChangeDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _saveCurrentPage(pageIndex);
      _preCacheNeighbors(pageNumber);
    });
  }

  Future<void> _preCacheNeighbors(int pageNumber) async {
    // Current page is already being loaded/shown, pre-cache next and previous
    if (pageNumber < 604) {
      _cachePage(pageNumber + 1);
    }
    if (pageNumber > 1) {
      _cachePage(pageNumber - 1);
    }
    // Also next-next
    if (pageNumber < 603) {
      _cachePage(pageNumber + 2);
    }
  }

  Future<void> _cachePage(int pageNumber) async {
    if (pageCache.containsKey(pageNumber)) return;
    try {
      final words = await _repo.getPageWords(pageNumber);
      pageCache[pageNumber] = words;
    } catch (e) {
      // debugPrint('Error pre-caching page $pageNumber: $e');
    }
  }

  Future<List<QuranWord>> getOrLoadPageWords(int pageNumber) async {
    if (pageCache.containsKey(pageNumber)) {
      return pageCache[pageNumber]!;
    }
    final words = await _repo.getPageWords(pageNumber);
    pageCache[pageNumber] = words;
    return words;
  }

  void navigateToSurah(int surahNumber) async {
    await _repo.navigateToSurah(surahNumber);
  }

  Future<void> navigateToVerse({
    required int surahNumber,
    required int verseNumber,
  }) async {
    await _repo.navigateToVerse(surahNumber, verseNumber);
    // Store coordinates — text-based matching is unreliable
    // because a single word's text can't contain the full verse string.
    emit(
      state.copyWith(
        highlightedSurah: surahNumber,
        highlightedAyah: verseNumber,
      ),
    );
  }

  // Called when Surah list PageView changes (zero-based index)
  Future<void> onSurahListChanged(int surahIndex) async {
    await _repo.onSurahListChanged(surahIndex);
    int juzNum = getCurrentJuzNumber(
      surahNumber: surahIndex + 1,
      verseNumber: 1,
    );

    emit(state.copyWith(juzNumber: juzNum));
  }

  void initControllers(int pageIndex) {
    _repo.initControllers(pageIndex);
    // Silent background preloader for perfectly smooth page experience
    QuranWbwDbHelper.instance.preloadAllPagesInBackground();

    final pageData = getPageData(pageIndex + 1);
    int juzNum = getCurrentJuzNumber(
      surahNumber: pageData[0]['surah'],
      verseNumber: pageData[0]['start'],
    );
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageIndex));
  }

  void changeLayout() {
    final nextLayout = state.layout == QuranLayout.min ? QuranLayout.full : QuranLayout.min;
    AppLogger.log('Quran', 'Double-tap layout switched to ${nextLayout.name}');

    if (state.layout == QuranLayout.min) {
      emit(
        state.copyWith(
          layout: QuranLayout.full,
          currentPage: state.currentPage,
        ),
      );
      _saveCurrentLayout(QuranLayout.full);
    } else {
      emit(
        state.copyWith(layout: QuranLayout.min, currentPage: state.currentPage),
      );
      _saveCurrentLayout(QuranLayout.min);
    }
  }

  void jumpToWird({required int startPage, required int endPage, required int index}) {
    emit(state.copyWith(
      wirdStartPage: startPage,
      targetEndPage: endPage,
      wirdIndex: index,
      currentPage: startPage - 1,
    ));
    navigateToPage(startPage - 1);
  }

  /// Reset the intro tutorial so it can be shown again
  Future<void> resetIntroTutorial() async {
    await IntroService.resetDoubleTapIntro();
  }

  void updateState(QuranState newState) {
    emit(newState);
  }

  void setAutoScrollSpeed(double speed) {
    emit(state.copyWith(autoScrollSpeed: speed));
  }

  void setAutoScrollPaused(bool paused) {
    emit(state.copyWith(isAutoScrollPaused: paused));
  }

  void toggleAutoScroll() {
    if (state.isAutoScrolling) {
      stopAutoScroll();
    } else {
      emit(state.copyWith(isAutoScrolling: true, isAutoScrollPaused: false));
    }
  }

  void stopAutoScroll() {
    emit(state.copyWith(isAutoScrolling: false, isAutoScrollPaused: false));
  }

  /// Set color for regular Mushaf only (does NOT change app theme).
  void setPaperColor(Color? color) {
    getIt<CacheService>().setInt(_quranColorKey, color?.toARGB32() ?? -1);
    emit(
      state.copyWith(quranPaperColor: color, clearPaperColor: color == null),
    );
  }

  /// Set color for Wird Mushaf only (does NOT change app theme).
  void setWirdColor(Color? color) {
    getIt<CacheService>().setInt(_wirdColorKey, color?.toARGB32() ?? -1);
    emit(state.copyWith(wirdPaperColor: color, clearWirdColor: color == null));
  }

  /// Set color for Kahf Mushaf only.
  void setKahfColor(Color? color) {
    getIt<CacheService>().setInt(_kahfColorKey, color?.toARGB32() ?? -1);
    emit(state.copyWith(kahfPaperColor: color, clearKahfColor: color == null));
  }

  /// Set the horizontal margin for Mushaf pages.
  void setPageMargin(double margin) {
    final clamped = margin.clamp(0.0, 40.0);
    getIt<CacheService>().setDouble(_quranMarginKey, clamped);
    emit(state.copyWith(quranPageMargin: clamped));
  }

  void toggleExporting(bool value) {
    emit(state.copyWith(isExporting: value));
  }
}
