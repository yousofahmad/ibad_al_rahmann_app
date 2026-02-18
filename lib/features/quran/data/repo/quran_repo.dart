import 'package:flutter/material.dart';
import 'package:quran/quran.dart';

class QuranRepo {
  // Controllers (owned by repo)
  late PageController pagesController;
  late PageController surahsController;
  late PageController minQuranController;
  late PageController fullQuranController;

  QuranRepo({bool tablet = false, int? initialPage}) {
    final int page = initialPage ?? 0;

    pagesController = PageController(
      viewportFraction: .125,
      initialPage: page,
    );

    // Set the initial surah based on the page
    int surahInitialPage = 0;
    if (page > 0) {
      final int surahNumber = _getSurahNumByPage(page + 1);
      surahInitialPage = surahNumber - 1; // Convert to 0-based index
    }

    surahsController = PageController(
      viewportFraction: .55,
      initialPage: surahInitialPage,
    );

    // Update current surah tracking
    if (page > 0) {
      _currentSurah = _getSurahNumByPage(page + 1);
    }

    if (tablet) {
      minQuranController = PageController(
        viewportFraction: .7,
        initialPage: page,
      );
    } else {
      minQuranController = PageController(
        viewportFraction: .85,
        initialPage: page,
      );
    }

    fullQuranController = PageController(
      viewportFraction: 1,
      initialPage: page,
    );
  }

  // Guards to avoid feedback loops when syncing controllers
  bool _suppressQuranChanged = false;
  bool _suppressPagesChanged = false;
  bool _suppressSurahsChanged = false;

  // Track current surah to detect changes
  int _currentSurah = 1;

  // Navigation and sync logic
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

  Future<void> navigateToVerse(int surahNumber, int verseNumber) async {
    // Compute target 0-based page for the verse
    final int page = getPageNumber(surahNumber, verseNumber) - 1;

    _suppressQuranChanged = true;
    _suppressPagesChanged = true;
    _suppressSurahsChanged = true;
    try {
      await Future.wait([
        minQuranController.animateToPage(
          page,
          duration: const Duration(milliseconds: 500),
          curve: Curves.linearToEaseOut,
        ),
        pagesController.animateToPage(
          page,
          duration: const Duration(milliseconds: 500),
          curve: Curves.linearToEaseOut,
        ),
        surahsController.animateToPage(
          surahNumber - 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.linearToEaseOut,
        ),
      ]);
      _currentSurah = surahNumber;
    } finally {
      _suppressQuranChanged = false;
      _suppressPagesChanged = false;
      _suppressSurahsChanged = false;
    }
  }

  Future<void> navigateToSurah(int surahNumber) async {
    final List<int> surahPages = getSurahPages(surahNumber);
    final int page = surahPages.first - 1;

    _suppressQuranChanged = true;
    _suppressPagesChanged = true;
    _suppressSurahsChanged = true;
    try {
      await Future.wait([
        minQuranController.animateToPage(
          page,
          duration: const Duration(seconds: 1),
          curve: Curves.linearToEaseOut,
        ),
        pagesController.animateToPage(
          page,
          duration: const Duration(seconds: 1),
          curve: Curves.linearToEaseOut,
        ),
        surahsController.animateToPage(
          surahNumber - 1, // Convert to 0-based index
          duration: const Duration(seconds: 1),
          curve: Curves.linearToEaseOut,
        ),
      ]);
      _currentSurah = surahNumber;
    } finally {
      _suppressQuranChanged = false;
      _suppressPagesChanged = false;
      _suppressSurahsChanged = false;
    }
  }

  Future<void> onQuranPageChanged(int pageIndex) async {
    if (_suppressQuranChanged) return;

    final int target = pageIndex;
    final int currentPages = pagesController.hasClients
        ? (pagesController.page?.round() ?? pagesController.initialPage)
        : pagesController.initialPage;

    final List<Future<void>> pending = [];
    if (currentPages != target) {
      _suppressPagesChanged = true;
      pending.add(pagesController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linearToEaseOut,
      ));
    }
    // Check if surah changed alongside
    pending.add(_updateSurahsControllerIfChanged(pageIndex + 1));

    try {
      await Future.wait(pending);
    } finally {
      _suppressPagesChanged = false;
    }
  }

  Future<void> onPagesListChanged(int pageIndex) async {
    if (_suppressPagesChanged) return;

    _suppressQuranChanged = true;
    try {
      await Future.wait([
        minQuranController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.linearToEaseOut,
        ),
        _updateSurahsControllerIfChanged(pageIndex + 1),
      ]);
    } finally {
      _suppressQuranChanged = false;
    }
  }

  Future<void> onSurahListChanged(int surahIndex) async {
    if (_suppressSurahsChanged) return;
    await navigateToSurah(surahIndex + 1);
  }

  int _getSurahNumByPage(int pageNumber) {
    final pageData = getPageData(pageNumber)[0];
    final int page = pageData['surah'];
    return page;
  }

  Future<void> _updateSurahsControllerIfChanged(int pageNumber) async {
    final int newSurah = _getSurahNumByPage(pageNumber);
    if (newSurah != _currentSurah) {
      _suppressSurahsChanged = true;
      try {
        await surahsController.animateToPage(
          newSurah - 1, // Convert to 0-based index
          duration: const Duration(milliseconds: 300),
          curve: Curves.linearToEaseOut,
        );
      } finally {
        _suppressSurahsChanged = false;
      }
      _currentSurah = newSurah;
    }
  }

  //! Used to initialize all controllers after switching from full to mini layout
  //! Also used to initialize with cached page on app start
  void initControllers(int pageNumber) async {
    final int surahNumber = _getSurahNumByPage(pageNumber + 1);
    _suppressQuranChanged = true;
    _suppressPagesChanged = true;
    _suppressSurahsChanged = true;

    try {
      await Future.wait([
        minQuranController.animateToPage(
          pageNumber,
          duration: const Duration(milliseconds: 400),
          curve: Curves.linearToEaseOut,
        ),
        pagesController.animateToPage(
          pageNumber,
          duration: const Duration(milliseconds: 400),
          curve: Curves.linearToEaseOut,
        ),
        surahsController.animateToPage(
          surahNumber - 1, // Convert to 0-based index
          duration: const Duration(milliseconds: 400),
          curve: Curves.linearToEaseOut,
        ),
      ]);
      _currentSurah = surahNumber;
    } finally {
      _suppressQuranChanged = false;
      _suppressPagesChanged = false;
      _suppressSurahsChanged = false;
    }
  }
}
