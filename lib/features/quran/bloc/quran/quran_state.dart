part of 'quran_cubit.dart';

class QuranState {
  final QuranLayout layout;
  final int juzNumber;
  final int? currentPage;
  final String? highligthedVerse;

  /// Surah + ayah coordinates for the highlighted verse (set by Fehres / bookmark navigation).
  final int? highlightedSurah;
  final int? highlightedAyah;

  final bool isWirdMode;
  final bool isKahfMode;
  final String? khatmaId;
  final int? wirdStartPage;
  final int? targetEndPage;
  final int? wirdIndex;

  final bool isAutoScrolling;

  /// Color for the regular Mushaf pages (independent of app theme).
  final Color? quranPaperColor;

  /// Color for the Wird Mushaf pages (independent of app theme and quranPaperColor).
  final Color? wirdPaperColor;

  /// Color for the Kahf Mushaf pages.
  final Color? kahfPaperColor;

  final double autoScrollSpeed;
  final bool isAutoScrollPaused;

  /// Horizontal margin (in logical pixels) added to each Mushaf page side.
  final double quranPageMargin;

  /// Whether we are currently exporting an HD image (used to adjust font sizes).
  final bool isExporting;

  QuranState({
    required this.layout,
    required this.juzNumber,
    this.currentPage,
    this.highligthedVerse,
    this.isWirdMode = false,
    this.isKahfMode = false,
    this.khatmaId,
    this.wirdStartPage,
    this.targetEndPage,
    this.wirdIndex,
    this.isAutoScrolling = false,
    this.quranPaperColor,
    this.wirdPaperColor,
    this.kahfPaperColor,
    this.autoScrollSpeed = 0.5,
    this.isAutoScrollPaused = false,
    this.highlightedSurah,
    this.highlightedAyah,
    this.quranPageMargin = 16.0,
    this.isExporting = false,
  });

  QuranState copyWith({
    QuranLayout? layout,
    int? juzNumber,
    int? currentPage,
    String? highligthedVerse,
    bool clearHighligthedVerse = false,
    int? highlightedSurah,
    int? highlightedAyah,
    bool? isWirdMode,
    bool? isKahfMode,
    String? khatmaId,
    int? wirdStartPage,
    int? targetEndPage,
    int? wirdIndex,
    bool? isAutoScrolling,
    Color? quranPaperColor,
    bool clearPaperColor = false,
    Color? wirdPaperColor,
    bool clearWirdColor = false,
    Color? kahfPaperColor,
    bool clearKahfColor = false,
    double? autoScrollSpeed,
    bool? isAutoScrollPaused,
    double? quranPageMargin,
    bool? isExporting,
  }) {
    return QuranState(
      layout: layout ?? this.layout,
      juzNumber: juzNumber ?? this.juzNumber,
      currentPage: currentPage ?? this.currentPage,
      highligthedVerse: clearHighligthedVerse
          ? null
          : (highligthedVerse ?? this.highligthedVerse),
      highlightedSurah: clearHighligthedVerse
          ? null
          : (highlightedSurah ?? this.highlightedSurah),
      highlightedAyah: clearHighligthedVerse
          ? null
          : (highlightedAyah ?? this.highlightedAyah),
      isWirdMode: isWirdMode ?? this.isWirdMode,
      isKahfMode: isKahfMode ?? this.isKahfMode,
      khatmaId: khatmaId ?? this.khatmaId,
      wirdStartPage: wirdStartPage ?? this.wirdStartPage,
      targetEndPage: targetEndPage ?? this.targetEndPage,
      wirdIndex: wirdIndex ?? this.wirdIndex,
      isAutoScrolling: isAutoScrolling ?? this.isAutoScrolling,
      quranPaperColor: clearPaperColor
          ? null
          : (quranPaperColor ?? this.quranPaperColor),
      wirdPaperColor: clearWirdColor
          ? null
          : (wirdPaperColor ?? this.wirdPaperColor),
      kahfPaperColor: clearKahfColor
          ? null
          : (kahfPaperColor ?? this.kahfPaperColor),
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      isAutoScrollPaused: isAutoScrollPaused ?? this.isAutoScrollPaused,
      quranPageMargin: quranPageMargin ?? this.quranPageMargin,
      isExporting: isExporting ?? this.isExporting,
    );
  }
}

enum QuranLayout { full, min }
