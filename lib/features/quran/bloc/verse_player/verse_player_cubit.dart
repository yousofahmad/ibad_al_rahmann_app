import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran/quran.dart';
import 'package:quran/surahs_tashkeel.dart';

part 'verse_player_state.dart';

class VersePlayerCubit extends Cubit<VersePlayerState> {
  VersePlayerCubit() : super(VersePlayerInitial(showed: false)) {
    init();
  }
  final player = getIt<AudioPlayer>();

  VerseModel? currnetVerse;

  StreamSubscription<PlayerState>? playerStateSubscription;

  String? reciter;

  void init() async {
    reciter = await getIt<CacheService>().getString('reciter');
  }

  Map<String, String> reciters = {
    'ar.minshawi': 'محمد صديق المنشاوي',
    'ar.muhammadjibreel': 'محمد جبريل',
    'ar.muhammadayyoub': 'محمد أيوب',
  };

  void changeReciter(String value) {
    reciter = value;
    initVerse();
  }

  void verseListener() {
    playerStateSubscription = player.playerStateStream.listen((value) {
      if (value.processingState == ProcessingState.completed) {
        // Audio finished
        player.pause();
        player.seek(const Duration(milliseconds: 0));

        emit(VersePlayerInitial(showed: true));
        // or you can emit a dedicated Finished state
        // emit(VersePlayerFinished(surahNumber!, verseNumber!));
      }
    });
  }

  void setVerse({
    required int surahNumber,
    required int verseNumber,
    required String fontFamily,
    required String verse,
  }) {
    currnetVerse = VerseModel(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      verse: verse,
      fontFamily: fontFamily,
    );
  }

  Future<void> initVerse() async {
    if (currnetVerse != null) {
      if (player.playing) {
        player.stop();
        initVerse();
      }

      String ayahUrl = getAudioURLByVerse(
        currnetVerse!.surahNumber,
        currnetVerse!.verseNumber,
        reciter ?? reciters.keys.first,
      );

      emit(VersePlayerInitial(showed: true, loading: true));

      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(ayahUrl),
          tag: MediaItem(
            id: ayahUrl,
            title: surahArabicTashkel[currnetVerse!.surahNumber - 1],
            // artUri: Uri.parse(AppConstants.notificationImage),
          ),
        ),
        preload: true,
      );
      verseListener();
      emit(VersePlayerInitial(showed: true, loading: false));
    }
  }

  void handlePlayPause() {
    if (!state.loading) {
      if (player.playing) {
        player.pause();
      } else {
        player.play();
      }
    }
    emit(VersePlayerInitial(showed: true));
  }

  void show() {
    emit(VersePlayerInitial(showed: true));
  }

  void hide() {
    currnetVerse = null;
    playerStateSubscription?.cancel();
    if (player.playing) {
      player.stop();
    }
    emit(VersePlayerInitial(showed: false));
  }

  /// Toggle bookmark for current verse
  Future<bool> toggleBookmark() async {
    if (currnetVerse != null) {
      final isBookmarked = await BookmarkService.toggleBookmark(currnetVerse!);
      // emit(VersePlayerInitial(showed: true));
      return isBookmarked;
    }
    return false;
  }

  /// Check if current verse is bookmarked
  bool isCurrentVerseBookmarked() {
    if (currnetVerse != null) {
      return BookmarkService.isBookmarked(currnetVerse!);
    }
    return false;
  }

  /// Get all bookmarked verses
  List<VerseModel> getAllBookmarks() {
    return BookmarkService.getAllBookmarks();
  }

  /// Get bookmarked verses sorted by date
  List<VerseModel> getBookmarksSortedByDate() {
    return BookmarkService.getBookmarksSortedByDate();
  }
}
