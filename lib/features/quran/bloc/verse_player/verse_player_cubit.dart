import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
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

  void setVerse({
    required int surahNumber,
    required int verseNumber,
    required String fontFamily,
    required String verse,
    String? label,
  }) {
    currnetVerse = VerseModel(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      verse: verse,
      fontFamily: fontFamily,
      label: label,
    );
    // Emit state so the highlight shows in the UI immediately
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: false,
        currentVerse: currnetVerse,
      ),
    );
  }

  Future<void> initVerse() async {
    if (currnetVerse != null) {
      if (player.playing) {
        await player.stop();
      }

      String ayahUrl = getAudioURLByVerse(
        currnetVerse!.surahNumber,
        currnetVerse!.verseNumber,
        reciter ?? reciters.keys.first,
      );

      emit(
        VersePlayerInitial(
          showed: true,
          loading: true,
          currentVerse: currnetVerse,
        ),
      );

      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(ayahUrl),
          tag: MediaItem(
            id: ayahUrl,
            title: 'سورة ${surahArabicTashkel[currnetVerse!.surahNumber - 1]}',
            artist: 'الآية ${currnetVerse!.verseNumber.toArabicNums}',
            album: reciter != null && reciters.containsKey(reciter)
                ? reciters[reciter]
                : 'القارئ',
          ),
        ),
        preload: false,
      );

      verseListener();
      // Removed player.play() to prevent autoplay
      emit(
        VersePlayerInitial(
          showed: true,
          loading: false,
          currentVerse: currnetVerse,
        ),
      );
    }
  }

  void verseListener() {
    playerStateSubscription?.cancel();
    playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
          ),
        );
      } else if (playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading) {
        emit(
          VersePlayerInitial(
            showed: true,
            loading: true,
            currentVerse: currnetVerse,
          ),
        );
      } else if (playerState.processingState == ProcessingState.ready) {
        emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
          ),
        );
      }
    });
  }

  void handlePlayPause() {
    if (!state.loading) {
      if (player.playing) {
        player.pause();
      } else {
        player.play();
      }
      // Re-emit state to trigger UI update for the play/pause icon
      emit(
        VersePlayerInitial(
          showed: true,
          loading: false,
          currentVerse: currnetVerse,
        ),
      );
    }
  }

  void show() {
    emit(VersePlayerInitial(showed: true, currentVerse: currnetVerse));
  }

  void hide() {
    currnetVerse = null;
    playerStateSubscription?.cancel();
    if (player.playing) {
      player.stop();
    }
    emit(VersePlayerInitial(showed: false, currentVerse: null));
  }

  /// Toggle bookmark for current verse with optional label
  Future<bool> toggleBookmark({String? label}) async {
    if (currnetVerse != null) {
      // Create a new VerseModel to ensure the label is correctly captured.
      final verseToBookmark = VerseModel(
        surahNumber: currnetVerse!.surahNumber,
        verseNumber: currnetVerse!.verseNumber,
        verse: currnetVerse!.verse,
        fontFamily: currnetVerse!.fontFamily,
        label: label, // Use the new label passed to this method.
      );

      final isBookmarked = await BookmarkService.toggleBookmark(
        verseToBookmark,
      );

      // Emit state to refresh UI icons immediately
      emit(
        VersePlayerInitial(
          showed: state.showed,
          loading: state.loading,
          currentVerse: currnetVerse,
        ),
      );

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
