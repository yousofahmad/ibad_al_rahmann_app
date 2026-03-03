part of 'quran_cubit.dart';

class QuranState {
  final QuranLayout layout;
  final int juzNumber;
  final int? currentPage;
  final String? highligthedVerse;

  final bool isWirdMode;
  final int? wirdStartPage;
  final int? targetEndPage;
  final int? wirdIndex;

  QuranState({
    required this.layout,
    required this.juzNumber,
    this.currentPage,
    this.highligthedVerse,
    this.isWirdMode = false,
    this.wirdStartPage,
    this.targetEndPage,
    this.wirdIndex,
  });

  QuranState copyWith({
    QuranLayout? layout,
    int? juzNumber,
    int? currentPage,
    String? highligthedVerse,
    bool? isWirdMode,
    int? wirdStartPage,
    int? targetEndPage,
    int? wirdIndex,
  }) {
    return QuranState(
      layout: layout ?? this.layout,
      juzNumber: juzNumber ?? this.juzNumber,
      currentPage: currentPage ?? this.currentPage,
      highligthedVerse: highligthedVerse ?? this.highligthedVerse,
      isWirdMode: isWirdMode ?? this.isWirdMode,
      wirdStartPage: wirdStartPage ?? this.wirdStartPage,
      targetEndPage: targetEndPage ?? this.targetEndPage,
      wirdIndex: wirdIndex ?? this.wirdIndex,
    );
  }
}

enum QuranLayout { full, min }
