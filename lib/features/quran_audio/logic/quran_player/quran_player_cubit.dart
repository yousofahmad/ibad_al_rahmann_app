import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../../core/di/di.dart';
import '../../data/surah_list.dart';

part 'quran_player_state.dart';

class QuranPlayerCubit extends Cubit<QuranPlayerState> {
  QuranPlayerCubit() : super(QuranPlayerInitial());
  final player = getIt<AudioPlayer>();
  Duration sliderPosition = Duration.zero;
  String? currentReciterName;
  ReciterModel? reciter;
  // StreamSubscription? positionSubscription, stateSubscription;
  int? selectedSurah;

  void unShowBottomSheet() {
    emit(QuranBottomSheetUnshowed());
  }

  String getSurahUrl(int surahNum) {
    return '${reciter!.moshafList[0].server}${surahNum.toString().padLeft(3, '0')}.mp3';
  }

  Future<void> playNextSurah(BuildContext context) async {
    try {
      if (selectedSurah! == 114) {
        emit(QuranPlayerFailure(errMessage: 'لا يوجد سورة بعد الناس'));
        emit(QuranBottomSheetShowed());
        return;
      }
      final nextSurah = selectedSurah! + 1;

      await init(nextSurah);
      playSurah(nextSurah);
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'حدث خطأ ما'));
    }
  }

  Future<void> playPreviousSurah(BuildContext context) async {
    try {
      if (selectedSurah! == 1) {
        emit(QuranPlayerFailure(errMessage: 'لا يوجد سورة قبل الفاتحة'));
        emit(QuranBottomSheetShowed());
        return;
      }
      final previousSurah = selectedSurah! - 1;

      await init(previousSurah);
      playSurah(previousSurah);
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'حدث خطأ ما'));
    }
  }

  Future<void> init(int surahNum) async {
    currentReciterName = reciter?.name;
    try {
      selectedSurah = surahNum;
      final url = getSurahUrl(surahNum);
      await player.setAudioSource(
        LockCachingAudioSource(
          Uri.parse(url),
          tag: MediaItem(
            id: '${reciter?.name} - ${quranSurahs[surahNum - 1]}',
            title: quranSurahs[surahNum - 1],
          ),
        ),
        preload: true,
      );

      emit(QuranBottomSheetShowed());
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'حدث خطأ ما'));
    }
  }

  void handlePlayPause() async {
    // if (player.playerState.processingState == ProcessingState.completed) {
    //   log('ProcessingState.completed');
    // }
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
    emit(QuranBottomSheetShowed());
  }

  void playSurah(int surah) async {
    if (player.playing && surah != selectedSurah) {
      player.stop();
      sliderPosition = Duration.zero;
    }

    if (selectedSurah != surah) {
      await init(surah);
    }

    handlePlayPause();
    emit(QuranBottomSheetShowed());
  }
}
