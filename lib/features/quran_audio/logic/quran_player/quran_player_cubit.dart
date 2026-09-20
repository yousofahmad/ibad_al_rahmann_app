import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../data/surah_list.dart';

part 'quran_player_state.dart';

class QuranPlayerCubit extends Cubit<QuranPlayerState> {
  QuranPlayerCubit() : super(QuranPlayerInitial());
  final player = AudioPlayer();
  Duration sliderPosition = Duration.zero;
  String? currentReciterName;
  ReciterAudioModel? reciter;
  int? selectedSurah;
  Map<String, VerseTiming> currentSegments = {};
  double currentSpeed = 1.0;
  bool isLooping = false;

  void unShowBottomSheet() {
    emit(QuranBottomSheetUnshowed());
  }

  Future<String> getSurahUrl(int surahNum) async {
    if (reciter != null) {
      final isOffline = await ReciterAudioHelper.isSurahDownloaded(reciter!.folderName, surahNum);
      if (isOffline) {
        return await ReciterAudioHelper.getOfflineSurahPath(reciter!.folderName, surahNum);
      }
      final surahs = await ReciterAudioHelper.getSurahs(reciter!);
      if (surahs.containsKey(surahNum)) {
        return surahs[surahNum]!.audioUrl;
      }
      return 'https://audio-cdn.tarteel.ai/quran/surah/${reciter!.folderName}/murattal/mp3/${surahNum.toString().padLeft(3, '0')}.mp3';
    }
    return '';
  }

  Future<void> playNextSurah(BuildContext context) async {
    try {
      if (selectedSurah == null || selectedSurah! >= 114) {
        emit(QuranPlayerFailure(errMessage: 'لا توجد سورة بعد سورة الناس'));
        emit(QuranBottomSheetShowed());
        return;
      }
      final nextSurah = selectedSurah! + 1;
      await playSurah(nextSurah);
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'حدث خطأ أثناء تشغيل السورة التالية'));
    }
  }

  Future<void> playPreviousSurah(BuildContext context) async {
    try {
      if (selectedSurah == null || selectedSurah! <= 1) {
        emit(QuranPlayerFailure(errMessage: 'لا توجد سورة قبل سورة الفاتحة'));
        emit(QuranBottomSheetShowed());
        return;
      }
      final previousSurah = selectedSurah! - 1;
      await playSurah(previousSurah);
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'حدث خطأ أثناء تشغيل السورة السابقة'));
    }
  }

  Future<void> init(int surahNum) async {
    currentReciterName = reciter?.name;
    try {
      selectedSurah = surahNum;
      final url = await getSurahUrl(surahNum);

      if (reciter != null && reciter!.hasSegments) {
        currentSegments = await ReciterAudioHelper.getSegments(reciter!);
      }

      final surahTitle = (surahNum >= 1 && surahNum <= quranSurahs.length)
          ? quranSurahs[surahNum - 1]
          : 'سورة $surahNum';

      if (url.startsWith('http')) {
        await player.setAudioSource(
          LockCachingAudioSource(
            Uri.parse(url),
            tag: MediaItem(
              id: '${reciter?.name} - $surahTitle',
              title: surahTitle,
              artist: reciter?.name ?? 'القارئ',
            ),
          ),
          preload: true,
        );
      } else {
        await player.setAudioSource(
          AudioSource.file(
            url,
            tag: MediaItem(
              id: '${reciter?.name} - $surahTitle',
              title: surahTitle,
              artist: reciter?.name ?? 'القارئ',
            ),
          ),
        );
      }

      emit(QuranBottomSheetShowed());
    } catch (e) {
      emit(QuranPlayerFailure(errMessage: 'تعذر تحميل ملف الصوت'));
    }
  }

  void setSpeed(double speed) {
    currentSpeed = speed;
    player.setSpeed(speed);
    emit(QuranBottomSheetShowed());
  }

  void toggleLoop() {
    isLooping = !isLooping;
    player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
    emit(QuranBottomSheetShowed());
  }

  void handlePlayPause() async {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
    emit(QuranBottomSheetShowed());
  }

  Future<void> playSurah(int surah) async {
    if (player.playing && surah != selectedSurah) {
      player.stop();
      sliderPosition = Duration.zero;
    }

    if (selectedSurah != surah) {
      await init(surah);
    }

    player.play();
    emit(QuranBottomSheetShowed());
  }

  void seekToVerse(int verseNumber) {
    if (selectedSurah != null) {
      final key = '$selectedSurah:$verseNumber';
      final timing = currentSegments[key];
      if (timing != null) {
        player.seek(Duration(milliseconds: timing.timestampFrom));
      }
    }
  }

  Future<void> changeReciter(ReciterAudioModel newReciter) async {
    reciter = newReciter;
    currentReciterName = newReciter.name;
    if (selectedSurah != null) {
      if (player.playing) {
        await player.stop();
      }
      await init(selectedSurah!);
    }
  }

  @override
  Future<void> close() async {
    await player.stop();
    await player.dispose();
    return super.close();
  }
}

