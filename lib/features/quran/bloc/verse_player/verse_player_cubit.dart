import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran/quran.dart';
import 'package:quran/surahs_tashkeel.dart';
part 'verse_player_state.dart';

typedef PairedSurahLoader =
    Future<(Map<int, SurahAudioItem>, Map<String, VerseTiming>)> Function(
      ReciterAudioModel reciter,
    );

class VersePlayerCubit extends Cubit<VersePlayerState> {
  VersePlayerCubit({
    AudioPlayer? audioPlayer,
    Future<Map<String, VerseTiming>> Function(ReciterAudioModel)? timingLoader,
    PairedSurahLoader? surahLoader,
    this.loadTimeout = const Duration(seconds: 20),
    this.autoHideDelay = const Duration(seconds: 4),
  }) : player = audioPlayer ?? AudioPlayer(),
       _timingLoader = timingLoader ?? ReciterAudioHelper.getSegments,
       _surahLoader = surahLoader ?? _loadPairedSurahMetadata,
       super(VersePlayerInitial(showed: false)) {
    init();
    verseListener();
  }

  final AudioPlayer player;
  final Future<Map<String, VerseTiming>> Function(ReciterAudioModel)
  _timingLoader;
  final PairedSurahLoader _surahLoader;

  static Future<(Map<int, SurahAudioItem>, Map<String, VerseTiming>)>
  _loadPairedSurahMetadata(ReciterAudioModel reciter) async {
    final values = await Future.wait<Object>([
      ReciterAudioHelper.getSurahs(reciter),
      ReciterAudioHelper.getSegments(reciter),
    ]);
    return (
      values[0] as Map<int, SurahAudioItem>,
      values[1] as Map<String, VerseTiming>,
    );
  }

  final Duration loadTimeout;
  final Duration autoHideDelay;
  VerseModel? currnetVerse;
  StreamSubscription<PlayerState>? playerStateSubscription;
  StreamSubscription<Duration>? positionSubscription;
  String? reciter;
  double playbackSpeed = 1.0;
  bool isLooping = false;
  bool autoPlayNext = false;
  bool isHighlightWordByWord =
      CacheHelper.prefs.getBool('verse_player_highlight_wbw') ?? true;
  ReciterAudioModel? currentReciterModel;
  Timer? _hideTimer;
  bool _hasAudioSession = false;
  bool _initialAutoHidePending = false;
  int _loadGeneration = 0;
  int _clipStartMs = 0;
  bool _sourceReady = false;
  bool _isChangingVerse = false;
  List<WordSegment> _wordSegments = const [];

  bool get isPlaying => player.playing;
  bool get hasAudioSession => _hasAudioSession;

  void _emitPlayback({
    bool? showed,
    bool? loading,
    int? word,
    bool updateWord = false,
    String? error,
    bool clearError = false,
  }) {
    if (isClosed) return;
    emit(
      VersePlayerInitial(
        showed: showed ?? state.showed,
        loading: loading ?? state.loading,
        currentVerse: currnetVerse,
        activeWordIndex: updateWord ? word : state.activeWordIndex,
        errorMessage: clearError ? null : error ?? state.errorMessage,
      ),
    );
  }

  void hideUiOnly() {
    _initialAutoHidePending = false;
    _hideTimer?.cancel();
    _emitPlayback(showed: false);
  }

  void toggleUiOnly() {
    if (!hasAudioSession) return;
    state.showed ? hideUiOnly() : showPlayer();
  }

  void showPlayer() {
    _initialAutoHidePending = false;
    _hideTimer?.cancel();
    if (currnetVerse != null) _emitPlayback(showed: true);
  }

  // Only the initial playback of a session may hide automatically. A manual
  // tap pins visibility until the next tap, regardless of buffering/verse changes.
  void _startHideTimer() {
    if (!_initialAutoHidePending ||
        _hideTimer != null ||
        !player.playing ||
        player.processingState != ProcessingState.ready) {
      return;
    }
    _hideTimer = Timer(autoHideDelay, () {
      _hideTimer = null;
      if (isClosed || !_initialAutoHidePending || !hasAudioSession) return;
      _initialAutoHidePending = false;
      _emitPlayback(showed: false);
    });
  }

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
    final modelFolder = currentReciterModel?.everyAyahFolder;
    final folder = modelFolder != null && modelFolder.isNotEmpty
        ? modelFolder
        : reciterFolders[reciterId];
    if (folder == null) throw StateError('لا يوجد مصدر آيات لهذا القارئ');
    final s = surahNumber.toString().padLeft(3, '0');
    final v = verseNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$v.mp3';
  }

  static const _legacyIds = {
    'ar.alafasy': 'mishari_alafasy',
    'ar.minshawi': 'minshawi_murattal',
    'ar.minshawimujawwad': 'minshawi_mujawwad',
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

  ReciterAudioModel? _resolveReciter(String id) {
    final mapped = _legacyIds[id] ?? id;
    for (final model in ReciterAudioHelper.availableReciters) {
      if (model.id == mapped) return model;
    }
    return null;
  }

  Map<String, String> get reciters => defaultReciters;
  static List<ReciterAudioModel> get allReciters =>
      ReciterAudioHelper.availableReciters;

  void init() {
    reciter =
        CacheHelper.prefs.getString('verse_player_reciter') ??
        CacheHelper.prefs.getString('reciter') ??
        defaultReciters.keys.first;
    autoPlayNext = CacheHelper.prefs.getBool('verse_player_auto_play') ?? false;
    currentReciterModel = _resolveReciter(reciter!);
  }

  void changeReciter(String value) {
    reciter = value;
    currentReciterModel = _resolveReciter(value);
    CacheHelper.prefs.setString('verse_player_reciter', value);
    if (currnetVerse != null) unawaited(initVerse(autoPlay: player.playing));
  }

  void selectReciter(ReciterAudioModel model) {
    reciter = model.id;
    currentReciterModel = model;
    CacheHelper.prefs.setString('verse_player_reciter', model.id);
    if (currnetVerse != null) unawaited(initVerse(autoPlay: player.playing));
  }

  void changePlaybackSpeed(double speed) {
    playbackSpeed = speed;
    unawaited(player.setSpeed(speed));
    _emitPlayback();
  }

  void toggleLoop() {
    isLooping = !isLooping;
    unawaited(player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off));
    _emitPlayback();
  }

  void setHighlightMode(bool wordByWord) {
    isHighlightWordByWord = wordByWord;
    CacheHelper.prefs.setBool('verse_player_highlight_wbw', wordByWord);
    _updatePosition(player.position);
    _emitPlayback();
  }

  void toggleHighlightMode() => setHighlightMode(!isHighlightWordByWord);

  void toggleAutoPlayNext() {
    autoPlayNext = !autoPlayNext;
    CacheHelper.prefs.setBool('verse_player_auto_play', autoPlayNext);
    _emitPlayback();
  }

  void setVerse({
    required int surahNumber,
    required int verseNumber,
    required String fontFamily,
    required String verse,
    String? label,
  }) {
    // Invalidate late metadata and positions from the previous verse immediately.
    _loadGeneration++;
    positionSubscription?.cancel();
    positionSubscription = null;
    _wordSegments = const [];
    _clipStartMs = 0;
    _sourceReady = false;
    currnetVerse = VerseModel(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      verse: verse,
      fontFamily: fontFamily,
      label: label,
    );
    _emitPlayback(loading: false, updateWord: true, clearError: true);
  }

  Future<void> initVerse({bool autoPlay = false}) async {
    final verse = currnetVerse;
    if (verse == null || isClosed) return;
    final generation = ++_loadGeneration;
    final model = currentReciterModel;
    final activeReciter = reciter ?? defaultReciters.keys.first;
    final newSession = !_hasAudioSession;
    _hasAudioSession = true;
    if (newSession) _initialAutoHidePending = true;
    _sourceReady = false;
    _wordSegments = const [];
    await positionSubscription?.cancel();
    positionSubscription = null;
    if (!_isCurrent(generation)) return;
    _emitPlayback(
      showed: newSession ? true : null,
      loading: true,
      updateWord: true,
      clearError: true,
    );
    final sourceStarted = DateTime.now().toUtc();
    final sourceWatch = Stopwatch()..start();
    var sourceKind = model?.zipFileName != null
        ? 'per_ayah_archive'
        : 'ayah_or_surah';
    String? sourceFailureReason;
    AppLogger.logEvent('VersePlayer', 'source_load_started', {
      'source': 'selected_reciter_audio',
      'trigger': 'ayah_init',
      'source_kind': sourceKind,
      'operation': generation,
      'actual_start': sourceStarted.toIso8601String(),
    });
    try {
      await player.stop();
      if (!_isCurrent(generation)) return;
      VerseTiming? timing;
      SurahAudioItem? pairedSurah;
      var usePairedClip = false;
      // ZIP metadata contains the authoritative per-ayah audio URL. Its timing
      // must be used with that exact recording, not another reciter/CDN take.
      if (model?.zipFileName != null) {
        final timings = await _timingLoader(model!).timeout(loadTimeout);
        if (!_isCurrent(generation)) return;
        timing = timings['${verse.surahNumber}:${verse.verseNumber}'];
        if (timing?.audioUrl == null || timing!.audioUrl!.isEmpty) {
          throw StateError('تعذر العثور على تسجيل الآية لهذا القارئ');
        }
      } else if (model != null &&
          model.hasSegments &&
          model.segmentsFileName != null) {
        final started = DateTime.now().toUtc();
        final watch = Stopwatch()..start();
        AppLogger.logEvent('VersePlayer', 'paired_source_load_started', {
          'trigger': 'ayah_init',
          'source_kind': 'paired_surah_clip',
          'actual_start': started.toIso8601String(),
        });
        try {
          final paired = await _surahLoader(model).timeout(loadTimeout);
          if (!_isCurrent(generation)) return;
          pairedSurah = paired.$1[verse.surahNumber];
          timing = paired.$2['${verse.surahNumber}:${verse.verseNumber}'];
          final audioUri = pairedSurah == null
              ? null
              : Uri.tryParse(pairedSurah.audioUrl);
          final approvedSource =
              audioUri != null &&
              (model.localOnly
                  ? await FeatureResourceRepository.configured.containsFileUri(
                      audioUri,
                    )
                  : audioUri.scheme == 'https' &&
                        audioUri.host.isNotEmpty &&
                        audioUri.userInfo.isEmpty);
          if (!_isCurrent(generation)) return;
          usePairedClip =
              pairedSurah != null &&
              pairedSurah.surahNumber == verse.surahNumber &&
              approvedSource &&
              timing != null &&
              timing.surahNumber == verse.surahNumber &&
              timing.verseNumber == verse.verseNumber &&
              timing.timestampFrom >= 0 &&
              timing.timestampTo > timing.timestampFrom;
          AppLogger.logEvent('VersePlayer', 'paired_source_load_finished', {
            'trigger': 'ayah_init',
            'source_kind': 'paired_surah_clip',
            'actual_start': started.toIso8601String(),
            'actual_finish': DateTime.now().toUtc().toIso8601String(),
            'duration_ms': watch.elapsedMilliseconds,
            'outcome': usePairedClip ? 'verified' : 'fallback_unverified',
            'reason': usePairedClip
                ? 'matched_and_bounded'
                : 'missing_or_invalid_metadata',
          });
          if (!usePairedClip) timing = null;
        } catch (_) {
          AppLogger.logEvent('VersePlayer', 'paired_source_load_finished', {
            'trigger': 'ayah_init',
            'source_kind': 'paired_surah_clip',
            'actual_start': started.toIso8601String(),
            'actual_finish': DateTime.now().toUtc().toIso8601String(),
            'duration_ms': watch.elapsedMilliseconds,
            'outcome': 'fallback_unverified',
            'reason': 'metadata_load_failed',
          });
        }
      }
      final ayahUrl = usePairedClip
          ? pairedSurah!.audioUrl
          : timing?.audioUrl ??
                getAyahAudioUrl(
                  verse.surahNumber,
                  verse.verseNumber,
                  activeReciter,
                  model,
                );
      sourceKind = usePairedClip
          ? 'paired_surah_clip'
          : model?.zipFileName != null
          ? 'per_ayah_archive'
          : 'every_ayah';
      final tag = MediaItem(
        id: ayahUrl,
        title: 'سورة ${surahArabicTashkel[verse.surahNumber - 1]}',
        artist: 'الآية ${verse.verseNumber.toArabicNums}',
        album: model?.name ?? defaultReciters[activeReciter] ?? 'القارئ',
      );
      final uriSource = AudioSource.uri(Uri.parse(ayahUrl), tag: tag);
      final source = usePairedClip
          ? ClippingAudioSource(
              child: uriSource,
              start: Duration(milliseconds: timing!.timestampFrom),
              end: Duration(milliseconds: timing.timestampTo),
              tag: tag,
              duration: Duration(
                milliseconds: timing.timestampTo - timing.timestampFrom,
              ),
            )
          : uriSource;
      await player.setAudioSource(source, preload: true).timeout(loadTimeout);
      if (!_isCurrent(generation)) return;
      await player.setSpeed(playbackSpeed);
      await player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
      if (!_isCurrent(generation)) return;
      _sourceReady = true;
      _clipStartMs = usePairedClip ? timing!.timestampFrom : 0;
      _emitPlayback(loading: false, clearError: true);
      if (timing != null) {
        _listenToSegments(timing, generation, clipStartMs: _clipStartMs);
      } else if (model != null &&
          model.hasSegments &&
          model.segmentsFileName == null) {
        unawaited(_loadSegmentsAsync(model, verse, generation, ayahUrl));
      }
      if (autoPlay) _play(generation);
    } catch (e) {
      sourceFailureReason = e.runtimeType.toString();
      if (!_isCurrent(generation)) return;
      AppLogger.logEvent('VersePlayer', 'source_load_failed', {
        'trigger': 'ayah_init',
        'reason': e.runtimeType.toString(),
      });
      // Abort a timed-out native load so it cannot start later on its own.
      await player.stop();
      if (!_isCurrent(generation)) return;
      _emitPlayback(
        loading: false,
        error: 'تعذر تحميل التلاوة. اضغط تشغيل للمحاولة مرة أخرى.',
      );
    } finally {
      AppLogger.logEvent('VersePlayer', 'source_load_finished', {
        'source': 'selected_reciter_audio',
        'trigger': 'ayah_init',
        'source_kind': sourceKind,
        'operation': generation,
        'actual_start': sourceStarted.toIso8601String(),
        'actual_finish': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': sourceWatch.elapsedMilliseconds,
        'outcome': !_isCurrent(generation)
            ? 'superseded'
            : _sourceReady
            ? 'success'
            : 'failed',
        'reason': sourceFailureReason,
      });
    }
  }

  bool _isCurrent(int generation) => !isClosed && generation == _loadGeneration;

  Future<void> _loadSegmentsAsync(
    ReciterAudioModel model,
    VerseModel verse,
    int generation,
    String expectedAudioUrl,
  ) async {
    final started = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    var outcome = 'unmatched';
    String? reason;
    AppLogger.logEvent('VersePlayer', 'timing_load_started', {
      'source': 'selected_ayah_metadata',
      'trigger': 'ayah_playback',
      'actual_start': started.toIso8601String(),
    });
    try {
      final timings = await _timingLoader(model).timeout(loadTimeout);
      if (!_isCurrent(generation)) {
        outcome = 'superseded';
        return;
      }
      final timing = timings['${verse.surahNumber}:${verse.verseNumber}'];
      if (timing != null && timing.audioUrl == expectedAudioUrl) {
        _listenToSegments(timing, generation, clipStartMs: _clipStartMs);
        outcome = 'verified';
      }
    } catch (e) {
      outcome = 'failed';
      reason = e.runtimeType.toString();
    } finally {
      AppLogger.logEvent('VersePlayer', 'timing_load_finished', {
        'source': 'selected_ayah_metadata',
        'trigger': 'ayah_playback',
        'actual_start': started.toIso8601String(),
        'actual_finish': DateTime.now().toUtc().toIso8601String(),
        'duration_ms': watch.elapsedMilliseconds,
        'outcome': outcome,
        'reason': reason,
      });
    }
  }

  void _listenToSegments(
    VerseTiming timing,
    int generation, {
    int clipStartMs = 0,
  }) {
    if (!_isCurrent(generation)) return;
    _wordSegments = timing.segments;
    _clipStartMs = clipStartMs;
    _updatePosition(player.position);
    positionSubscription?.cancel();
    positionSubscription = player.positionStream.listen((position) {
      if (_isCurrent(generation)) _updatePosition(position);
    });
  }

  void _updatePosition(Duration position) {
    int? word;
    if (isHighlightWordByWord) {
      final offset =
          _wordSegments.isNotEmpty && _wordSegments.first.wordIndex == 0
          ? 1
          : 0;
      final ms = position.inMilliseconds + _clipStartMs;
      for (final segment in _wordSegments) {
        if (ms >= segment.startMs && ms < segment.endMs) {
          word = segment.wordIndex + offset;
          break;
        }
      }
    }
    if (word != state.activeWordIndex) {
      _emitPlayback(word: word, updateWord: true);
    }
  }

  void _play(int generation) {
    unawaited(
      player.play().catchError((Object e) {
        if (_isCurrent(generation)) {
          _emitPlayback(
            loading: false,
            error: 'تعذر تشغيل التلاوة. حاول مرة أخرى.',
          );
        }
      }),
    );
  }

  void verseListener() {
    playerStateSubscription?.cancel();
    playerStateSubscription = player.playerStateStream.listen((playerState) {
      if (isClosed || !hasAudioSession) return;
      final processing = playerState.processingState;
      if (processing == ProcessingState.ready && playerState.playing) {
        _startHideTimer();
      }
      if (processing == ProcessingState.completed && _sourceReady) {
        _sourceReady =
            false; // Consume completion once, before the next async load.
        if (autoPlayNext && !isLooping) {
          unawaited(playNextVerse());
        } else {
          unawaited(player.pause());
          unawaited(player.seek(Duration.zero));
          _sourceReady = true;
          _emitPlayback(loading: false);
        }
      } else if (processing == ProcessingState.buffering ||
          processing == ProcessingState.loading) {
        _emitPlayback(loading: true);
      } else if (processing == ProcessingState.ready) {
        _emitPlayback(loading: false);
      } else {
        _emitPlayback();
      }
    });
  }

  Future<void> playNextVerse() async {
    if (_isChangingVerse || currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      var surah = currnetVerse!.surahNumber;
      var verse = currnetVerse!.verseNumber + 1;
      if (verse > getVerseCount(surah)) {
        if (surah == 114) {
          await player.pause();
          _emitPlayback(loading: false);
          return;
        }
        surah++;
        verse = 1;
      }
      setVerse(
        surahNumber: surah,
        verseNumber: verse,
        fontFamily: 'UthmanicHafs',
        verse: getVerse(surah, verse),
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
  }

  Future<void> playPreviousVerse() async {
    if (_isChangingVerse || currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      var surah = currnetVerse!.surahNumber;
      var verse = currnetVerse!.verseNumber - 1;
      if (verse < 1) {
        if (surah == 1) return;
        surah--;
        verse = getVerseCount(surah);
      }
      setVerse(
        surahNumber: surah,
        verseNumber: verse,
        fontFamily: 'UthmanicHafs',
        verse: getVerse(surah, verse),
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
  }

  void handlePlayPause() {
    if (state.loading || currnetVerse == null) return;
    if (!_sourceReady || state.errorMessage != null) {
      unawaited(initVerse(autoPlay: true));
    } else if (player.playing) {
      unawaited(player.pause());
    } else {
      _play(_loadGeneration);
    }
    _emitPlayback();
  }

  void show() => showPlayer();

  void hide() {
    _loadGeneration++;
    _hideTimer?.cancel();
    _hideTimer = null;
    _hasAudioSession = false;
    _initialAutoHidePending = false;
    _sourceReady = false;
    _wordSegments = const [];
    positionSubscription?.cancel();
    positionSubscription = null;
    currnetVerse = null;
    unawaited(player.stop());
    _emitPlayback(
      showed: false,
      loading: false,
      updateWord: true,
      clearError: true,
    );
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
      _emitPlayback();

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
    _loadGeneration++;
    _hideTimer?.cancel();
    await playerStateSubscription?.cancel();
    await positionSubscription?.cancel();
    await player.stop();
    await player.dispose();
    return super.close();
  }
}
