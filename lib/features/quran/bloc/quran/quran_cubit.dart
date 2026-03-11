import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/data/quran_word.dart';
import 'package:ibad_al_rahmann/features/quran/data/db_helper.dart'; // Ensure db helper import
import 'package:quran/quran.dart';

part 'quran_state.dart';

class QuranCubit extends Cubit<QuranState> {
  final bool isWirdMode;
  final int? wirdStartPage;
  final int? targetEndPage;
  final int? wirdIndex;
  final Map<int, List<QuranWord>> pageCache = {};

  /// Keys for RepaintBoundary per page – used for HD page capture.
  final Map<int, GlobalKey> pageKeys = {};

  /// Returns (or creates) a GlobalKey for the given [pageNumber].
  GlobalKey getPageKey(int pageNumber) {
    return pageKeys.putIfAbsent(pageNumber, () => GlobalKey());
  }

  QuranCubit(
    this._repo, {
    this.isWirdMode = false,
    this.wirdStartPage,
    this.targetEndPage,
    this.wirdIndex,
  }) : super(
         QuranState(
           layout: QuranLayout.min,
           juzNumber: 1,
           isWirdMode: isWirdMode,
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

  /// Initialize cache and load the last page
  Future<void> _initializeCache() async {
    await getIt<CacheService>().init();
    await _loadLastPage();
  }

  /// Load the last page from cache and set it as initial page
  Future<void> _loadLastPage() async {
    final key = isWirdMode ? _lastWirdPageKey : _lastPageKey;
    int? lastPage = getIt<CacheService>().getInt(key);
    final String? lastLayoutString = await getIt<CacheService>().getString(
      _lastLayoutKey,
    );

    if (lastPage != null) {
      final int pageNumber = lastPage + 1;
      final QuranLayout layout = lastLayoutString == 'full'
          ? QuranLayout.full
          : QuranLayout.min;
      final pageData = getPageData(pageNumber);
      int juzNum = getCurrentJuzNumber(
        surahNumber: pageData[0]['surah'],
        verseNumber: pageData[0]['start'],
      );
      emit(
        state.copyWith(
          layout: layout,
          juzNumber: juzNum,
          currentPage: lastPage,
        ),
      );
    }
  }

  /// Save the current page to cache
  Future<void> _saveCurrentPage(int pageIndex) async {
    final key = state.isWirdMode ? _lastWirdPageKey : _lastPageKey;
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
    if (state.highligthedVerse != null) {
      emit(state.copyWith(clearHighligthedVerse: true));
    }
  }

  // Called when Quran PageView page changes (zero-based index)
  Future<void> onQuranPageChanged(int pageIndex) async {
    await _repo.onQuranPageChanged(pageIndex);
    final pageNumber = pageIndex + 1;
    final pageData = getPageData(pageNumber);
    int juzNum = getCurrentJuzNumber(
      surahNumber: pageData[0]['surah'],
      verseNumber: pageData[0]['start'],
    );
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageIndex));
    clearHighlightedVerse();
    await _saveCurrentPage(pageIndex);
    _preCacheNeighbors(pageNumber);
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

    final String verse = getVerseQCF(
      surahNumber,
      verseNumber,
    ).replaceAll(' ', '');
    if (verse.isNotEmpty) {
      final String highlighted =
          '${verse.substring(0, 1)}\u200A${verse.substring(1)}';
      emit(state.copyWith(highligthedVerse: highlighted));
    }
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

  void initControllers(int pageNumber) {
    _repo.initControllers(pageNumber);
    // Silent background preloader for perfectly smooth page experience
    QuranWbwDbHelper.instance.preloadAllPagesInBackground();

    final pageData = getPageData(pageNumber == 0 ? 1 : pageNumber);
    int juzNum = getCurrentJuzNumber(
      surahNumber: pageData[0]['surah'],
      verseNumber: pageData[0]['start'],
    );
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageNumber - 1));
  }

  void changeLayout() {
    if (state.layout == QuranLayout.min) {
      int pageIndex = minQuranController.hasClients
          ? (minQuranController.page?.round() ?? 1)
          : 1;
      emit(state.copyWith(layout: QuranLayout.full, currentPage: pageIndex));
      _saveCurrentLayout(QuranLayout.full);
    } else {
      int pageIndex = fullQuranController.hasClients
          ? (fullQuranController.page?.round() ?? 1)
          : 1;
      emit(state.copyWith(layout: QuranLayout.min, currentPage: pageIndex));
      _saveCurrentLayout(QuranLayout.min);
    }
  }

  /// Reset the intro tutorial so it can be shown again
  Future<void> resetIntroTutorial() async {
    await IntroService.resetDoubleTapIntro();
  }

  void updateState(QuranState newState) {
    emit(newState);
  }
}
