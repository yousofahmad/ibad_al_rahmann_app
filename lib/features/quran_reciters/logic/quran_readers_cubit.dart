import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/networking/api_keys.dart';
import 'package:ibad_al_rahmann/core/networking/dio_consumer.dart';

import '../data/models/reciter_model.dart';

part 'quran_readers_state.dart';

class QuranReadersCubit extends Cubit<QuranReadersState> {
  QuranReadersCubit() : super(QuranReadersInitial()) {
    getQuranReaders();
  }
  var searchController = TextEditingController();

  void onSearch(String? value) {
    if (value != null) {
      List<ReciterModel> searchReciters = reciters
          .where((e) => e.name.contains(value))
          .toList();
      emit(QuranReadersSuccess(reciters: searchReciters));
    } else {
      emit(QuranReadersSuccess(reciters: reciters));
    }
  }

  List<ReciterModel> reciters = [];

  Future<void> getQuranReaders() async {
    emit(QuranReadersLoading());
    try {
      var response = await getIt<DioConsumer>().get(
        ApiKeys.recitersBaseUrl,
        queryParameters: {'language': 'ar'},
      );
      final List recitersList = response.data[ApiKeys.reciters];
      reciters = recitersList
          .map((qaree) => ReciterModel.fromJson(qaree))
          .toList();

      emit(QuranReadersSuccess(reciters: reciters));
    } catch (e) {
      // log(e.toString());
      emit(QuranReadersFailure(errMessage: 'يرجى التحقق من الإنترنت'));
    }
  }
  // Future<void> getQuranReaders() async {
  //   emit(QuranReadersLoading());
  //   try {
  //     var response = await getIt<DioConsumer>().get(
  //       ApiKeys.qurraaBaseUrl,
  //       queryParameters: {'language': 'ar'},
  //     );

  //     List qurraaAsMaps = response[ApiKeys.recitations];

  //     reciters =
  //         qurraaAsMaps.map((qaree) => ReciterModel.fromJson(qaree)).toList();

  //     reciters.removeWhere((qaree) => qaree.id == 8);
  //     reciters.removeWhere((qaree) => qaree.id == 2);
  //     reciters.removeWhere((qaree) => qaree.id == 3);
  //     reciters.removeWhere((qaree) => qaree.id == 5);
  //     reciters.removeWhere((qaree) => qaree.id == 11);
  //     reciters.removeWhere((qaree) => qaree.id == 12);

  //     reciters.sort((a, b) => b.name.compareTo(a.name));

  //     for (var qaree in reciters) {
  //       log('${qaree.name} ${qaree.id} ${qaree.style}');
  //     }

  //     emit(QuranReadersSuccess(reciters: reciters));
  //   } catch (e) {
  //     log(e.toString());
  //     emit(
  //       QuranReadersFailure(errMessage: 'يرجى التحقق من الإنترنت'),
  //     );
  //   }
  // }
}
