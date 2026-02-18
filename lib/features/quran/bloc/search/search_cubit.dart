import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_verse_model.dart';
import 'package:quran/quran.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchInitial());
  final controller = TextEditingController();
  String removeArabicDiacritics(String input) {
    final regex =
        RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
    return input.replaceAll(regex, '');
  }

  void onSearch(String value) {
    // ayahs.clear();
    if (value.length <= 2) {
      emit(OnSearch(verses: []));
    } else if (value.length > 2) {
      // ayahs.clear();
      final ayahsData = searchWords(value);
      // final count = ayahsData['occurences'] > 20 ? 20 : ayahsData['occurences'];
      List result = ayahsData['result'];

      List<SearchingVerseModel> allAyahs = [];
      for (var i = 0; i < ayahsData['occurences']; i++) {
        allAyahs.add(SearchingVerseModel(
          verseNumber: result[i]['verse'],
          surahNumber: result[i]['surah'],
          content: result[i]['content'],
        ));
      }

      emit(OnSearch(verses: allAyahs));
    }
  }

  void clear() {
    controller.clear();
    emit(OnSearch(verses: []));
  }
}
