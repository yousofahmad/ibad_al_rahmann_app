part of 'quran_cubit.dart';

class QuranState {
  final QuranLayout layout;
  final int juzNumber;
  final int? currentPage;
  final String? highligthedVerse;

  QuranState({
    required this.layout,
    required this.juzNumber,
    this.currentPage,
    this.highligthedVerse,
  });

  QuranState copyWith({
    QuranLayout? layout,
    int? juzNumber, 
    int? currentPage,
    String? highligthedVerse
  }) {
    return QuranState(
      layout: layout ?? this.layout,
      juzNumber: juzNumber ?? this.juzNumber,
      currentPage: currentPage ?? this.currentPage,
      highligthedVerse: highligthedVerse ?? this.highligthedVerse,
    );
  }
}

enum QuranLayout { full, min }
