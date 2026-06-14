import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/networking/dio_consumer.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

import '../../../../core/networking/api_keys.dart';
import '../../data/models/surah_audio_model.dart';

part 'quran_state.dart';

class QuranAudioCubit extends Cubit<QuranState> {
  QuranAudioCubit(this.reciter) : super(QuranInitial());
  final ReciterModel reciter;

  List<SurahAudioModel> quran = [];

  Future<List<SurahAudioModel>> getQuran(int qareeId) async {
    emit(QuranLoading());
    try {
      int moshafIndex = 0;
      String url = '${reciter.moshafList[moshafIndex].server}/$qareeId';

      var response = await getIt<DioConsumer>().get(
        url,
        headers: {'content-type': 'application/json'},
      );

      log(response.toString());

      List quranAsMaps = response.data['data'][ApiKeys.audioFiles];

      quran = quranAsMaps.map((e) => SurahAudioModel.fromJson(e)).toList();

      emit(QuranSuccess());

      return quran;
    } on DioException catch (e) {
      emit(QuranFailure(errMessage: e.message ?? 'هناك خطأ'));
      return [];
    }
  }
}
