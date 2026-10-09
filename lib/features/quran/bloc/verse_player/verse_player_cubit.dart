import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran/quran.dart';
import 'package:quran/surahs_tashkeel.dart';

part 'verse_player_state.dart';

class VersePlayerCubit extends Cubit<VersePlayerState> {
  VersePlayerCubit() : super(VersePlayerInitial(showed: false)) {
    init();
  }
  AudioPlayer player = AudioPlayer();

  VerseModel? currnetVerse;

  StreamSubscription<PlayerState>? playerStateSubscription;
  StreamSubscription<Duration>? positionSubscription;

  String? reciter;
  double playbackSpeed = 1.0;
  bool isLooping = false;
  bool autoPlayNext = true;
  Timer? _hideTimer;

  void showPlayer() {
    _hideTimer?.cancel();
    if (currnetVerse != null) {
      emit(VersePlayerInitial(showed: true, loading: state.loading, currentVerse: currnetVerse, activeWordIndex: state.activeWordIndex));
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (player.playing && currnetVerse != null) {
        emit(VersePlayerInitial(showed: false, loading: state.loading, currentVerse: currnetVerse, activeWordIndex: state.activeWordIndex));
      }
    });
  }
  bool isHighlightWordByWord =
      CacheHelper.prefs.getBool('verse_player_highlight_wbw') ?? true;
  ReciterAudioModel? currentReciterModel;

  static const Map<String, String> defaultReciters = {
    'ar.alafasy': 'مشاري راشد العفاسي',
    'ar.minshawi': 'محمد صديق المنشاوي (مرتل)',
    'ar.minshawimujawwad': 'محمد صديق المنشاوي (مجود)',
    'ar.abdulbasitmurattal': 'عبد الباسط عبد الصمد (مرتل)',
    'ar.abdulbasitmujawwad': 'عبد الباسط عبد الصمد (مجود)',
    'ar.husary': 'محمود خليل الحصري (مرتل)',
    'ar.husarymuallim': 'محمود خليل الحصري (معلم)',
    'ar.saoodshuraym': 'سعود الشريم',
    'ar.abdurrahmaansudais': 'عبد الرحمن السديس',
    'ar.mahermuaiqly': 'ماهر المعيقلي',
    'ar.yasseraddossari': 'ياسر الدوسري',
    'ar.saadalghamdi': 'سعد الغامدي',
    'ar.ahmedajamy': 'أحمد بن علي العجمي',
    'ar.muhammadjibreel': 'محمد جبريل',
    'ar.muhammadayyoub': 'محمد أيوب',
    'ar.hudhaify': 'علي بن عبد الرحمن الحذيفي',
    'ar.abdullahbasfar': 'عبد الله بصفر',
    'ar.faresabbad': 'فارس عباد',
    'ar.shaatree': 'أبو بكر الشاطري',
    'ar.banna': 'محمود علي البنا',
    'ar.tablawi': 'محمد محمود الطبلاوي',
    'ar.hazzaalbalushi': 'هزاع البلوشي',
    'ar.nasserqatami': 'ناصر القطامي',
    'ar.khaledalqahtani': 'خالد القحطاني',
    'ar.ali_jaber': 'عبد الله علي جابر',
    'ar.aljuhany': 'عبد الله عواد الجهني',
    'ar.aymanswoid': 'أيمن سويد',
    'ar.mustafaismail': 'مصطفى إسماعيل',
    'ar.muhsin_al_qasim': 'محسن القاسم',
    'ar.salahbudair': 'صلاح بدير',
    'ar.salahbukhatir': 'صلاح بو خاطر',
    'ar.abdullahmatroud': 'عبد الله المطرود',
  };

  static const Map<String, String> reciterFolders = {
    'ar.alafasy': 'Alafasy_128kbps',
    'ar.minshawi': 'Minshawy_Murattal_128kbps',
    'ar.minshawimujawwad': 'Minshawy_Mujawwad_192kbps',
    'ar.abdulbasitmurattal': 'Abdul_Basit_Murattal_192kbps',
    'ar.abdulbasitmujawwad': 'Abdul_Basit_Mujawwad_128kbps',
    'ar.husary': 'Husary_128kbps',
    'ar.husarymuallim': 'Husary_Muallim_128kbps',
    'ar.saoodshuraym': 'Saood_ash-Shuraym_128kbps',
    'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
    'ar.mahermuaiqly': 'Maher_AlMuaiqly_64kbps',
    'ar.yasseraddossari': 'Yasser_Ad-Dussary_128kbps',
    'ar.saadalghamdi': 'Ghamadi_40kbps',
    'ar.ahmedajamy': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_kotSimple',
    'ar.muhammadjibreel': 'Muhammad_Jibreel_128kbps',
    'ar.muhammadayyoub': 'Muhammad_Ayyoub_128kbps',
    'ar.hudhaify': 'Hudhaify_128kbps',
    'ar.abdullahbasfar': 'Abdullah_Basfar_192kbps',
    'ar.faresabbad': 'Fares_Abbad_64kbps',
    'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps',
    'ar.banna': 'Mahmoud_Ali_Al_Banna_32kbps',
    'ar.tablawi': 'Mohammad_al_Tablaway_128kbps',
    'ar.hazzaalbalushi': 'Haza_Al_Balushi_128kbps',
    'ar.nasserqatami': 'Nasser_Alqatami_128kbps',
    'ar.khaledalqahtani': 'Khaalid_Al-Qahtaanee_192kbps',
    'ar.ali_jaber': 'Ali_Jaber_64kbps',
    'ar.aljuhany': 'Abdullaah_3li_Jabbir_32kbps',
    'ar.aymanswoid': 'Ayman_Sowaid_64kbps',
    'ar.mustafaismail': 'Mustafa_Ismail_48kbps',
    'ar.muhsin_al_qasim': 'Muhsin_Al_Qasim_192kbps',
    'ar.salahbudair': 'Salah_Al_Budair_128kbps',
    'ar.salahbukhatir': 'Salah_Bukhatir_128kbps',
    'ar.abdullahmatroud': 'Abdullah_Matroud_128kbps',
  };

  static String getAyahAudioUrl(
    int surahNumber,
    int verseNumber,
    String reciterId,
    ReciterAudioModel? currentReciterModel,
  ) {
    final folder = currentReciterModel?.everyAyahFolder ?? reciterFolders[reciterId] ?? 'Alafasy_128kbps';
    final s = surahNumber.toString().padLeft(3, '0');
    final v = verseNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$v.mp3';
  }

  Map<String, String> get reciters => defaultReciters;

  void init() async {
    reciter =
        CacheHelper.prefs.getString('reciter') ?? defaultReciters.keys.first;
    autoPlayNext = CacheHelper.prefs.getBool('verse_player_auto_play') ?? false;
  }

  void changeReciter(String value) {
    reciter = value;
    CacheHelper.prefs.setString('reciter', value);
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
      ),
    );
    initVerse(autoPlay: player.playing);
  }

  void changePlaybackSpeed(double speed) {
    playbackSpeed = speed;
    player.setSpeed(speed);
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
      ),
    );
  }

  void toggleLoop() {
    isLooping = !isLooping;
    player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
      ),
    );
  }

  static List<ReciterAudioModel> get allReciters =>
      ReciterAudioHelper.defaultReciters;

  void selectReciter(ReciterAudioModel model) {
    reciter = model.id;
    currentReciterModel = model;
    CacheHelper.prefs.setString('verse_player_reciter', model.id);
    if (currnetVerse != null) {
      initVerse(autoPlay: player.playing);
    }
  }

  void setHighlightMode(bool wordByWord) {
    isHighlightWordByWord = wordByWord;
    CacheHelper.prefs.setBool('verse_player_highlight_wbw', wordByWord);
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
        activeWordIndex: isHighlightWordByWord ? state.activeWordIndex : null,
      ),
    );
  }

  void toggleHighlightMode() {
    isHighlightWordByWord = !isHighlightWordByWord;
    CacheHelper.prefs.setBool(
      'verse_player_highlight_wbw',
      isHighlightWordByWord,
    );
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
        activeWordIndex: state.activeWordIndex,
      ),
    );
  }

  void toggleAutoPlayNext() {
    autoPlayNext = !autoPlayNext;
    CacheHelper.prefs.setBool('verse_player_auto_play', autoPlayNext);
    emit(
      VersePlayerInitial(
        showed: state.showed,
        loading: state.loading,
        currentVerse: currnetVerse,
      ),
    );
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

  bool _isInitializingVerse = false;

  Future<void> initVerse({bool autoPlay = false}) async {
    if (_isInitializingVerse) return;
    _isInitializingVerse = true;
    try {
      if (currnetVerse != null) {
        if (player.playing) {
          await player.stop();
        }

        final activeReciter = reciter ?? defaultReciters.keys.first;

        // Compute direct EveryAyah CDN audio URL immediately (0ms delay)
        final ayahUrl = getAyahAudioUrl(
          currnetVerse!.surahNumber,
          currnetVerse!.verseNumber,
          activeReciter,
          currentReciterModel,
        );

        emit(
          VersePlayerInitial(
            showed: true,
            loading: true,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );

        try {
          await player.setAudioSource(
            AudioSource.uri(
              Uri.parse(ayahUrl),
              tag: MediaItem(
                id: ayahUrl,
                title:
                    'سورة ${surahArabicTashkel[currnetVerse!.surahNumber - 1]}',
                artist: 'الآية ${currnetVerse!.verseNumber.toArabicNums}',
                album: defaultReciters[activeReciter] ?? 'القارئ',
              ),
            ),
            preload: true,
          );

          await player.setSpeed(playbackSpeed);
          await player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
          verseListener();

          if (autoPlay) {
            player.play();
            _startHideTimer();
          }

          emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );

          // Fetch segments asynchronously in background for word-by-word highlight without delaying audio
          _loadSegmentsAsync(
            activeReciter,
            currnetVerse!.surahNumber,
            currnetVerse!.verseNumber,
          );
        } catch (e) {
          debugPrint('Error setting verse audio source: $e');
          emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );
        }
      }
    } finally {
      _isInitializingVerse = false;
    }
  }

  void _loadSegmentsAsync(
    String activeReciter,
    int surahNum,
    int verseNum,
  ) async {
    try {
      final recitersList = await ReciterAudioHelper.getReciters();
      final Map<String, String> everyAyahToReciterModelId = {
        'ar.alafasy': 'mishari_alafasy',
        'ar.minshawi': 'minshawi_murattal',
        'ar.abdulbasitmurattal': 'abdulbasit_murattal',
        'ar.abdulbasitmujawwad': 'abdulbasit_mujawwad',
        'ar.husary': 'mahmoud_husary_murattal',
        'ar.husarymuallim': 'husary_muallim',
        'ar.saoodshuraym': 'shuraim',
        'ar.abdurrahmaansudais': 'sudais',
        'ar.mahermuaiqly': 'muaiqly',
        'ar.yasseraddossari': 'dosari',
        'ar.saadalghamdi': 'ghamdi',
        'ar.muhammadjibreel': 'jibreel',
        'ar.muhammadayyoub': 'ayyoob',
        'ar.hudhaify': 'huthaify',
        'ar.abdullahbasfar': 'basfar',
        'ar.faresabbad': 'fares_abbad',
        'ar.shaatree': 'shatri',
        'ar.banna': 'banna',
        'ar.tablawi': 'tablawi',
        'ar.nasserqatami': 'qatami',
        'ar.ali_jaber': 'ali_jaber',
        'ar.aljuhany': 'juhani',
        'ar.mustafaismail': 'mustafa_ismail',
        'ar.salahbudair': 'budair',
        'ar.salahbukhatir': 'bukhatir',
        'ar.abdullahmatroud': 'matroud',
      };

      final mappedId =
          everyAyahToReciterModelId[activeReciter] ?? activeReciter;

      final reciterModel = recitersList.firstWhere(
        (r) => r.id == mappedId,
        orElse: () =>
            ReciterAudioModel(id: '', name: '', style: '', folderName: ''),
      );
      currentReciterModel = reciterModel;

      if (reciterModel.id.isNotEmpty || reciterModel.folderName.isNotEmpty) {
        final segmentsMap = await ReciterAudioHelper.getSegments(reciterModel);
        final key = '$surahNum:$verseNum';
        if (segmentsMap.containsKey(key)) {
          final timing = segmentsMap[key]!;
          final wordSegments = timing.segments;

          if (wordSegments.isNotEmpty &&
              currnetVerse?.surahNumber == surahNum &&
              currnetVerse?.verseNumber == verseNum) {
            positionSubscription?.cancel();
            positionSubscription = player.positionStream.listen((pos) {
              if (currnetVerse == null) return;
              final ms = pos.inMilliseconds;
              int? currentWord;
              if (isHighlightWordByWord) {
                for (final seg in wordSegments) {
                  if (ms >= seg.startMs && ms <= seg.endMs) {
                    currentWord = seg.wordIndex;
                    break;
                  }
                }
              }
              if (currentWord != state.activeWordIndex) {
                emit(
                  VersePlayerInitial(
                    showed: true,
                    loading: state.loading,
                    currentVerse: currnetVerse,
                    activeWordIndex: currentWord,
                  ),
                );
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void verseListener() {
    playerStateSubscription?.cancel();
    playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
      if (playerState.processingState == ProcessingState.completed) {
        if (autoPlayNext && !isLooping) {
          playNextVerse();
        } else {
          player.seek(Duration.zero);
          player.pause();
          emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );
        }
      } else if (playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading) {
        emit(
          VersePlayerInitial(
            showed: true,
            loading: true,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );
      } else if (playerState.processingState == ProcessingState.ready) {
        emit(
          VersePlayerInitial(
            showed: true,
            loading: false,
            currentVerse: currnetVerse,
            activeWordIndex: state.activeWordIndex,
          ),
        );
      }
    });
  }

  bool _isChangingVerse = false;

  Future<void> playNextVerse() async {
    if (_isChangingVerse) return;
    if (currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      final totalVersesInSurah = getVerseCount(currnetVerse!.surahNumber);
      int nextSNum = currnetVerse!.surahNumber;
      int nextVNum = currnetVerse!.verseNumber + 1;
      if (nextVNum > totalVersesInSurah) {
        if (nextSNum < 114) {
          nextSNum += 1;
          nextVNum = 1;
        } else {
          return;
        }
      }
      final nextText = getVerse(nextSNum, nextVNum);
      final nextPg = getPageNumber(nextSNum, nextVNum);
      final nextFont = 'page';

      setVerse(
        surahNumber: nextSNum,
        verseNumber: nextVNum,
        fontFamily: nextFont,
        verse: nextText,
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
  }

  Future<void> playPreviousVerse() async {
    if (_isChangingVerse) return;
    if (currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      int prevSNum = currnetVerse!.surahNumber;
      int prevVNum = currnetVerse!.verseNumber - 1;
      if (prevVNum < 1) {
        if (prevSNum > 1) {
          prevSNum -= 1;
          prevVNum = getVerseCount(prevSNum);
        } else {
          return;
        }
      }
      final prevText = getVerse(prevSNum, prevVNum);
      final prevPg = getPageNumber(prevSNum, prevVNum);
      final prevFont = 'page';

      setVerse(
        surahNumber: prevSNum,
        verseNumber: prevVNum,
        fontFamily: prevFont,
        verse: prevText,
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
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
            activeWordIndex: state.activeWordIndex,
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

  @override
  Future<void> close() async {
    playerStateSubscription?.cancel();
    positionSubscription?.cancel();
    await player.stop();
    await player.dispose();
    return super.close();
  }
}
