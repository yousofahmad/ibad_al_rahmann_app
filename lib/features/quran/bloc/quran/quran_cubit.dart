import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:quran/quran.dart';

part 'quran_state.dart';

class QuranCubit extends Cubit<QuranState> {
  QuranCubit(this._repo)
      : super(
          QuranState(layout: QuranLayout.min, juzNumber: 1),
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
  static const String _lastLayoutKey = 'last_quran_layout';

  /// Initialize cache and load the last page
  Future<void> _initializeCache() async {
    await getIt<CacheService>().init();
    await _loadLastPage();
  }

  /// Load the last page from cache and set it as initial page
  Future<void> _loadLastPage() async {
    int? lastPage = getIt<CacheService>().getInt(_lastPageKey);
    final String? lastLayoutString =
        await getIt<CacheService>().getString(_lastLayoutKey);

    if (lastPage != null) {
      lastPage++;
      final QuranLayout layout =
          lastLayoutString == 'full' ? QuranLayout.full : QuranLayout.min;
      final pageData = getPageData(lastPage);
      int juzNum = getCurrentJuzNumber(
          surahNumber: pageData[0]['surah'], verseNumber: pageData[0]['start']);
      emit(
        QuranState(
          layout: layout,
          juzNumber: juzNum,
          currentPage: lastPage,
        ),
      );
    }
  }

  /// Save the current page to cache
  Future<void> _saveCurrentPage(int pageIndex) async {
    await getIt<CacheService>().setInt(_lastPageKey, pageIndex);
  }

  /// Save the current layout to cache
  Future<void> _saveCurrentLayout(QuranLayout layout) async {
    await getIt<CacheService>().setString(_lastLayoutKey, layout.name);
  }

  PageController get pagesController => _repo.pagesController;
  PageController get surahsController => _repo.surahsController;
  PageController get minQuranController => _repo.minQuranController;
  PageController get fullQuranController => _repo.fullQuranController;

  int get currentSurahIndex => surahsController.page?.round() ?? 0;

  // Called when Pages list PageView changes (zero-based index)
  void onPagesListChanged(int pageIndex) async {
    await _repo.onPagesListChanged(pageIndex);
  }

  // Navigate Quran main pager to the given zero-based page index

  Future<void> navigateToPage(int pageIndex, {String? highligthedVerse}) async {
    await _repo.navigateToPage(pageIndex);

    if (highligthedVerse != null) {
      emit(
        state.copyWith(
            highligthedVerse:
                '${highligthedVerse.substring(0, 1)}\u200A${highligthedVerse.substring(1)}'),
      );
    }
  }

  // Clear the transient highlighted verse (e.g., after navigation/scroll)
  void clearHighlightedVerse() {
    if (state.highligthedVerse != null) {
      emit(
        QuranState(
          layout: state.layout,
          juzNumber: state.juzNumber,
          currentPage: state.currentPage,
          highligthedVerse: null,
        ),
      );
    }
  }

  // Called when Quran PageView page changes (zero-based index)
  Future<void> onQuranPageChanged(int pageIndex) async {
    await _repo.onQuranPageChanged(pageIndex);
    final pageData = getPageData(pageIndex + 1);
    int juzNum = getCurrentJuzNumber(
      surahNumber: pageData[0]['surah'],
      verseNumber: pageData[0]['start'],
    );
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageIndex));
    clearHighlightedVerse();
    // Save the current page to cache
    await _saveCurrentPage(pageIndex);
  }

  void navigateToSurah(int surahNumber) async {
    await _repo.navigateToSurah(surahNumber);
  }

  Future<void> navigateToVerse({
    required int surahNumber,
    required int verseNumber,
  }) async {
    await _repo.navigateToVerse(surahNumber, verseNumber);

    final String verse =
        getVerseQCF(surahNumber, verseNumber).replaceAll(' ', '');
    if (verse.isNotEmpty) {
      final String highlighted =
          '${verse.substring(0, 1)}\u200A${verse.substring(1)}';
      emit(state.copyWith(highligthedVerse: highlighted));
    }
  }

  // Called when Surah list PageView changes (zero-based index)
  Future<void> onSurahListChanged(int surahIndex) async {
    await _repo.onSurahListChanged(surahIndex);
    int juzNum =
        getCurrentJuzNumber(surahNumber: surahIndex + 1, verseNumber: 1);

    emit(state.copyWith(juzNumber: juzNum));
  }

  void initControllers(int pageNumber) {
    _repo.initControllers(pageNumber);
    final pageData = getPageData(pageNumber == 0 ? 1 : pageNumber);
    int juzNum = getCurrentJuzNumber(
        surahNumber: pageData[0]['surah'], verseNumber: pageData[0]['start']);
    emit(state.copyWith(juzNumber: juzNum, currentPage: pageNumber - 1));
  }

  void changeLayout() {
    if (state.layout == QuranLayout.min) {
      int pageIndex = minQuranController.page?.round() ?? 1;
      emit(
        QuranState(
          layout: QuranLayout.full,
          currentPage: pageIndex,
          juzNumber: state.juzNumber,
        ),
      );
      // Save the new layout to cache
      _saveCurrentLayout(QuranLayout.full);
    } else {
      int pageIndex = fullQuranController.page?.round() ?? 1;

      emit(
        QuranState(
          layout: QuranLayout.min,
          currentPage: pageIndex,
          juzNumber: state.juzNumber,
        ),
      );
      // Save the new layout to cache
      _saveCurrentLayout(QuranLayout.min);
    }
  }

  /// Reset the intro tutorial so it can be shown again
  Future<void> resetIntroTutorial() async {
    await IntroService.resetDoubleTapIntro();
  }
}
