import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/reciter_model.dart';

part 'quran_readers_state.dart';

enum QuranReciterFilter { wordByWord, verseOnly, surah }

class QuranReadersCubit extends Cubit<QuranReadersState> {
  QuranReadersCubit() : super(QuranReadersInitial()) {
    getQuranReaders();
  }
  final searchController = TextEditingController();
  QuranReciterFilter selectedFilter = QuranReciterFilter.surah;
  List<ReciterAudioModel> reciters = [];

  /// Pure filtering logic, independent of the remote reciter source.
  static List<ReciterAudioModel> filterReciters({
    required List<ReciterAudioModel> reciters,
    required QuranReciterFilter filter,
    String query = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return reciters.where((reciter) {
      final supportsFilter = switch (filter) {
        QuranReciterFilter.wordByWord =>
          reciter.highlightSupport == ReciterHighlightSupport.wordByWord,
        QuranReciterFilter.verseOnly =>
          reciter.highlightSupport == ReciterHighlightSupport.wordByWord ||
              reciter.highlightSupport == ReciterHighlightSupport.verseOnly,
        // All reciters expose a complete-surah recording.
        QuranReciterFilter.surah => true,
      };
      if (!supportsFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      return reciter.name.toLowerCase().contains(normalizedQuery) ||
          reciter.style.toLowerCase().contains(normalizedQuery) ||
          reciter.category.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  void onSearch(String? value) {
    _emitFiltered();
  }

  void selectFilter(QuranReciterFilter filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    _emitFiltered();
  }

  void _emitFiltered() {
    if (isClosed) return;
    emit(
      QuranReadersSuccess(
        reciters: filterReciters(
          reciters: reciters,
          filter: selectedFilter,
          query: searchController.text,
        ),
      ),
    );
  }

  Future<void> getQuranReaders() async {
    emit(QuranReadersLoading());
    try {
      reciters = List.from(ReciterAudioHelper.availableReciters);
      _emitFiltered();

      await ReciterAudioHelper.fetchRemoteReciters();
      if (isClosed) return;
      reciters = List.from(ReciterAudioHelper.availableReciters);
      _emitFiltered();
    } catch (e) {
      reciters = List.from(ReciterAudioHelper.defaultReciters);
      _emitFiltered();
    }
  }

  @override
  Future<void> close() {
    searchController.dispose();
    return super.close();
  }
}
