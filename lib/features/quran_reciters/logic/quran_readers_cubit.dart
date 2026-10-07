import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/reciter_model.dart';

part 'quran_readers_state.dart';

class QuranReadersCubit extends Cubit<QuranReadersState> {
  QuranReadersCubit() : super(QuranReadersInitial()) {
    getQuranReaders();
  }
  var searchController = TextEditingController();

  void onSearch(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      List<ReciterAudioModel> searchReciters = reciters
          .where(
            (e) =>
                e.name.contains(value) ||
                e.style.contains(value) ||
                e.category.contains(value),
          )
          .toList();
      emit(QuranReadersSuccess(reciters: searchReciters));
    } else {
      emit(QuranReadersSuccess(reciters: reciters));
    }
  }

  List<ReciterAudioModel> reciters = [];

  Future<void> getQuranReaders() async {
    emit(QuranReadersLoading());
    try {
      reciters = List.from(ReciterAudioHelper.availableReciters);
      emit(QuranReadersSuccess(reciters: reciters));

      await ReciterAudioHelper.fetchRemoteReciters();
      reciters = List.from(ReciterAudioHelper.availableReciters);
      emit(QuranReadersSuccess(reciters: reciters));
    } catch (e) {
      reciters = List.from(ReciterAudioHelper.defaultReciters);
      emit(QuranReadersSuccess(reciters: reciters));
    }
  }
}
