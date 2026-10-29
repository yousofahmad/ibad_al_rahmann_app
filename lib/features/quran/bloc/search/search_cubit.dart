import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_verse_model.dart';
import 'package:quran/quran.dart' show normalise;
import 'package:quran/quran_text.dart' as quran_data;

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchInitial());

  final controller = TextEditingController();

  static final List<_IndexedQuranVerse> _searchIndex = quran_data.quranText
      .map((verse) {
        final content = verse['content']?.toString() ?? '';
        return _IndexedQuranVerse(
          surahNumber: int.parse(verse['surah_number'].toString()),
          verseNumber: int.parse(verse['verse_number'].toString()),
          content: content,
          normalizedContent: _normalizeSearchText(content),
        );
      })
      .toList(growable: false);

  static String _normalizeSearchText(String input) => normalise(input)
      .replaceAll('\u0671', '\u0627') // Normalize alif wasla to alif.
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void onSearch(String value) {
    final query = _normalizeSearchText(value);
    if (query.length <= 2) {
      emit(OnSearch(verses: []));
      return;
    }

    final matches = <SearchingVerseModel>[];
    for (final verse in _searchIndex) {
      if (verse.normalizedContent.contains(query)) {
        matches.add(
          SearchingVerseModel(
            verseNumber: verse.verseNumber,
            surahNumber: verse.surahNumber,
            content: verse.content,
          ),
        );
      }
    }
    emit(OnSearch(verses: matches));
  }

  void clear() {
    controller.clear();
    emit(OnSearch(verses: []));
  }

  @override
  Future<void> close() {
    controller.dispose();
    return super.close();
  }
}

class _IndexedQuranVerse {
  final int surahNumber;
  final int verseNumber;
  final String content;
  final String normalizedContent;

  const _IndexedQuranVerse({
    required this.surahNumber,
    required this.verseNumber,
    required this.content,
    required this.normalizedContent,
  });
}
