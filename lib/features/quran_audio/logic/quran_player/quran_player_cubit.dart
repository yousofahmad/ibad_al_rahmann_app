import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../data/surah_list.dart';

part 'quran_player_state.dart';

class QuranPlayerCubit extends Cubit<QuranPlayerState> {
  QuranPlayerCubit() : super(QuranPlayerInitial()) {
    _initPlayerListener();
  }
  final player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Duration sliderPosition = Duration.zero;
  String? currentReciterName;
  ReciterAudioModel? reciter;
  int? selectedSurah;
  Map<String, VerseTiming> currentSegments = {};
  double currentSpeed = 1.0;
  bool isLooping = false;
  bool autoPlayNext = true;

  void _initPlayerListener() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        AppLogger.log("QuranAudio", "Surah $selectedSurah playback completed");
        if (!isLooping &&
            autoPlayNext &&
            selectedSurah != null &&
            selectedSurah! < 114) {
          AppLogger.log(
            "QuranAudio",
            "Auto-advancing to surah ${selectedSurah! + 1}",
          );
          playSurah(selectedSurah! + 1);
        }
      }
      if (selectedSurah != null) {
        emit(QuranBottomSheetShowed());
      }
    });
  }

  void toggleAutoPlayNext() {
    autoPlayNext = !autoPlayNext;
    AppLogger.log("QuranAudio", "toggleAutoPlayNext: $autoPlayNext");
    emit(QuranBottomSheetShowed());
  }

  void unShowBottomSheet() {
    emit(QuranBottomSheetUnshowed());
  }

  Future<String> getSurahUrl(int surahNum) async {
    if (reciter != null) {
      final isOffline = await ReciterAudioHelper.isSurahDownloaded(
        reciter!.folderName,
        surahNum,
      );
      if (isOffline) {
        final offlinePath = await ReciterAudioHelper.getOfflineSurahPath(
          reciter!.folderName,
          surahNum,
        );
        AppLogger.log(
          "QuranAudio",
          "getSurahUrl: using offline file for surah $surahNum: $offlinePath",
        );
        return offlinePath;
      }
      final surahs = await ReciterAudioHelper.getSurahs(reciter!);
      if (surahs.containsKey(surahNum)) {
        final url = surahs[surahNum]!.audioUrl;
        AppLogger.log(
          "QuranAudio",
          "getSurahUrl: using metadata url for surah $surahNum: $url",
        );
        return url;
      }
      final fallbackUrl =
          'https://audio-cdn.tarteel.ai/quran/surah/${reciter!.folderName}/murattal/mp3/${surahNum.toString().padLeft(3, '0')}.mp3';
      AppLogger.log(
        "QuranAudio",
        "getSurahUrl: using CDN fallback for surah $surahNum: $fallbackUrl",
      );
      return fallbackUrl;
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
      AppLogger.log("QuranAudio", "playNextSurah: $nextSurah");
      await playSurah(nextSurah);
    } catch (e) {
      AppLogger.log("QuranAudio", "playNextSurah error: $e");
      emit(
        QuranPlayerFailure(errMessage: 'حدث خطأ أثناء تشغيل السورة التالية'),
      );
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
      AppLogger.log("QuranAudio", "playPreviousSurah: $previousSurah");
      await playSurah(previousSurah);
    } catch (e) {
      AppLogger.log("QuranAudio", "playPreviousSurah error: $e");
      emit(
        QuranPlayerFailure(errMessage: 'حدث خطأ أثناء تشغيل السورة السابقة'),
      );
    }
  }

  Future<bool> init(int surahNum) async {
    currentReciterName = reciter?.name;
    try {
      selectedSurah = surahNum;
      final url = await getSurahUrl(surahNum);

      final surahTitle = (surahNum >= 1 && surahNum <= quranSurahs.length)
          ? quranSurahs[surahNum - 1]
          : 'سورة $surahNum';

      AppLogger.log(
        "QuranAudio",
        "init: surah $surahNum ($surahTitle) with reciter '${reciter?.name}' -> $url",
      );

      if (url.startsWith('http')) {
        await player.setAudioSource(
          AudioSource.uri(
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

      // Load segments asynchronously in background without blocking audio playback
      if (reciter != null && reciter!.hasSegments) {
        _loadSegmentsBackground(reciter!);
      }

      emit(QuranBottomSheetShowed());
      return true;
    } catch (e) {
      AppLogger.log("QuranAudio", "init error for surah $surahNum: $e");
      emit(QuranPlayerFailure(errMessage: 'تعذر تحميل ملف الصوت'));
      return false;
    }
  }

  void _loadSegmentsBackground(ReciterAudioModel reciterModel) async {
    try {
      final segments = await ReciterAudioHelper.getSegments(
        reciterModel,
      ).timeout(const Duration(seconds: 8));
      currentSegments = segments;
      AppLogger.log(
        "QuranAudio",
        "Loaded ${segments.length} segment timestamps for ${reciterModel.name}",
      );
    } catch (e) {
      AppLogger.log(
        "QuranAudio",
        "Segment timestamps not available for ${reciterModel.name}: $e",
      );
    }
  }

  void setSpeed(double speed) {
    currentSpeed = speed;
    player.setSpeed(speed);
    AppLogger.log("QuranAudio", "setSpeed: $speed");
    emit(QuranBottomSheetShowed());
  }

  void toggleLoop() {
    isLooping = !isLooping;
    player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
    AppLogger.log("QuranAudio", "toggleLoop: $isLooping");
    emit(QuranBottomSheetShowed());
  }

  void handlePlayPause() async {
    if (player.playing) {
      AppLogger.log("QuranAudio", "Paused surah $selectedSurah");
      player.pause();
    } else {
      AppLogger.log("QuranAudio", "Resumed surah $selectedSurah");
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      player.play();
    }
    emit(QuranBottomSheetShowed());
  }

  Future<void> playSurah(int surah) async {
    AppLogger.log("QuranAudio", "playSurah: $surah requested (current: $selectedSurah, playing: ${player.playing})");
    if (selectedSurah == surah) {
      handlePlayPause();
      return;
    }

    if (player.playing) {
      await player.stop();
      sliderPosition = Duration.zero;
    }

    selectedSurah = surah;
    emit(QuranBottomSheetShowed());

    final success = await init(surah);
    if (!success) {
      return;
    }

    await player.play();
  }

  void seekToVerse(int verseNumber) {
    if (selectedSurah != null) {
      final key = '$selectedSurah:$verseNumber';
      final timing = currentSegments[key];
      if (timing != null) {
        AppLogger.log(
          "QuranAudio",
          "seekToVerse: $key -> ${timing.timestampFrom}ms",
        );
        player.seek(Duration(milliseconds: timing.timestampFrom));
      } else {
        AppLogger.log("QuranAudio", "seekToVerse: no timing found for $key");
      }
    }
  }

  Future<void> changeReciter(ReciterAudioModel newReciter) async {
    AppLogger.log("QuranAudio", "changeReciter: '${newReciter.name}'");
    reciter = newReciter;
    currentReciterName = newReciter.name;
    if (selectedSurah != null) {
      final wasPlaying = player.playing;
      if (wasPlaying) {
        await player.stop();
      }
      final success = await init(selectedSurah!);
      if (success && wasPlaying) {
        await player.play();
      }
    }
  }

  @override
  Future<void> close() async {
    AppLogger.log("QuranAudio", "Closing QuranPlayerCubit");
    _playerStateSubscription?.cancel();
    await player.stop();
    await player.dispose();
    return super.close();
  }
}
