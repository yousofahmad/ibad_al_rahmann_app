import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/audio/verse_player.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAudioPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  bool active = false;
  ProcessingState processing = ProcessingState.idle;
  Duration currentPosition = Duration.zero;
  AudioSource? source;
  bool failLoad = false;
  Completer<Duration?>? pendingLoad;

  @override
  bool get playing => active;
  @override
  ProcessingState get processingState => processing;
  @override
  Duration get position => currentPosition;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;

  void sendState(ProcessingState value, {bool? playing}) {
    processing = value;
    if (playing != null) active = playing;
    states.add(PlayerState(active, processing));
  }

  void sendPosition(int ms) {
    currentPosition = Duration(milliseconds: ms);
    positions.add(currentPosition);
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource value, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = value;
    if (failLoad) throw StateError('load failed');
    if (pendingLoad != null) return pendingLoad!.future;
    currentPosition = Duration.zero;
    sendState(ProcessingState.ready);
    return const Duration(seconds: 10);
  }

  @override
  Future<void> play() async => sendState(ProcessingState.ready, playing: true);
  @override
  Future<void> pause() async => sendState(processing, playing: false);
  @override
  Future<void> stop() async => sendState(ProcessingState.idle, playing: false);
  @override
  Future<void> seek(Duration? value, {int? index}) async {
    currentPosition = value ?? Duration.zero;
  }

  @override
  Future<void> setSpeed(double value) async {}
  @override
  Future<void> setLoopMode(LoopMode value) async {}
  @override
  Future<void> dispose() async {
    await states.close();
    await positions.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> initPrefs() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  }

  setUp(initPrefs);

  VerseTiming timing(int verse) => VerseTiming(
    surahNumber: 1,
    verseNumber: verse,
    audioUrl: 'https://audio-cdn.tarteel.ai/quran/alnufais/00100$verse.mp3',
    timestampFrom: 0,
    timestampTo: 2500,
    durationMs: 2500,
    segments: [
      WordSegment(wordIndex: 1, startMs: 0, endMs: 500),
      WordSegment(wordIndex: 2, startMs: 800, endMs: 1200),
    ],
  );

  VersePlayerCubit build(
    TestAudioPlayer player, {
    Future<Map<String, VerseTiming>> Function(ReciterAudioModel)? loader,
    Duration timeout = const Duration(seconds: 20),
  }) {
    final cubit = VersePlayerCubit(
      audioPlayer: player,
      timingLoader: loader ?? (_) async => {'1:1': timing(1), '1:2': timing(2)},
      loadTimeout: timeout,
      autoHideDelay: const Duration(milliseconds: 20),
    );
    cubit.selectReciter(ReciterAudioHelper.getReciterById('ahmad_alnufais'));
    cubit.setVerse(
      surahNumber: 1,
      verseNumber: 1,
      fontFamily: 'UthmanicHafs',
      verse: 'بسم الله',
    );
    return cubit;
  }

  test(
    'Nufais uses the URL belonging to the same recording as word timings',
    () async {
      final player = TestAudioPlayer();
      final cubit = build(player);
      await cubit.initVerse(autoPlay: true);
      expect(
        (player.source as UriAudioSource).uri.toString(),
        timing(1).audioUrl,
      );
      expect(cubit.hasAudioSession, isTrue);
      expect(cubit.state.loading, isFalse);
      player.sendPosition(200);
      expect(cubit.state.activeWordIndex, 1);
      player.sendPosition(600);
      expect(cubit.state.activeWordIndex, isNull);
      player.sendPosition(900);
      expect(cubit.state.activeWordIndex, 2);
      cubit.setHighlightMode(false);
      expect(cubit.state.activeWordIndex, isNull);
      cubit.setHighlightMode(true);
      expect(cubit.state.activeWordIndex, 2);
      await cubit.close();
    },
  );

  test(
    'auto-hide happens once; manual visibility survives positions, pause, and verses',
    () async {
      final player = TestAudioPlayer();
      final cubit = build(player);
      await cubit.initVerse(autoPlay: true);
      expect(cubit.state.showed, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cubit.state.showed, isFalse);
      player.sendPosition(900);
      player.sendState(ProcessingState.buffering);
      player.sendState(ProcessingState.ready);
      expect(cubit.state.showed, isFalse);
      cubit.toggleUiOnly();
      expect(cubit.state.showed, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.showed, isTrue);
      cubit.handlePlayPause();
      expect(cubit.hasAudioSession, isTrue);
      cubit.toggleUiOnly();
      expect(cubit.state.showed, isFalse);
      await cubit.playNextVerse();
      expect(cubit.currnetVerse!.verseNumber, 2);
      expect(cubit.state.showed, isFalse);
      cubit.toggleUiOnly();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.showed, isTrue);
      cubit.hide();
      expect(cubit.hasAudioSession, isFalse);
      expect(cubit.currnetVerse, isNull);
      await cubit.close();
    },
  );

  test('load error clears spinner and play retries the same reciter', () async {
    final player = TestAudioPlayer()..failLoad = true;
    final cubit = build(player);
    await cubit.initVerse();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.errorMessage, isNotNull);
    player.failLoad = false;
    cubit.handlePlayPause();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.errorMessage, isNull);
    expect(player.playing, isTrue);
    await cubit.close();
  });

  test(
    'late metadata cannot overwrite a newer verse or reveal hidden controls',
    () async {
      final player = TestAudioPlayer();
      final old = Completer<Map<String, VerseTiming>>();
      var calls = 0;
      final cubit = build(
        player,
        loader: (_) {
          calls++;
          return calls == 1 ? old.future : Future.value({'1:2': timing(2)});
        },
      );
      final loadingOld = cubit.initVerse();
      await Future<void>.delayed(Duration.zero);
      cubit.setVerse(
        surahNumber: 1,
        verseNumber: 2,
        fontFamily: 'UthmanicHafs',
        verse: 'الحمد لله',
      );
      cubit.hideUiOnly();
      await cubit.initVerse(autoPlay: true);
      old.complete({'1:1': timing(1)});
      await loadingOld;
      expect(
        (player.source as UriAudioSource).uri.toString(),
        timing(2).audioUrl,
      );
      expect(cubit.state.showed, isFalse);
      expect(cubit.currnetVerse!.verseNumber, 2);
      await cubit.close();
    },
  );

  test('source timeout clears loading and cannot autoplay later', () async {
    final player = TestAudioPlayer()..pendingLoad = Completer<Duration?>();
    final cubit = build(player, timeout: const Duration(milliseconds: 5));
    await cubit.initVerse(autoPlay: true);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.errorMessage, isNotNull);
    player.pendingLoad!.complete(const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    expect(player.playing, isFalse);
    await cubit.close();
  });

  test(
    'hiding controls keeps audio; explicit close stops and clears session',
    () async {
      final player = TestAudioPlayer();
      final cubit = build(player);
      cubit.toggleAutoPlayNext();
      await cubit.initVerse(autoPlay: true);
      cubit.hideUiOnly();
      expect(player.playing, isTrue);
      expect(cubit.hasAudioSession, isTrue);

      cubit.hide();
      await Future<void>.delayed(Duration.zero);
      expect(player.playing, isFalse);
      expect(player.processingState, ProcessingState.idle);
      expect(cubit.hasAudioSession, isFalse);
      expect(cubit.currnetVerse, isNull);
      expect(cubit.state.showed, isFalse);
      expect(cubit.state.activeWordIndex, isNull);
      // A late completion must not advance or resurrect the closed session.
      player.sendState(ProcessingState.completed);
      cubit.toggleUiOnly();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.currnetVerse, isNull);
      expect(cubit.state.showed, isFalse);
      expect(player.playing, isFalse);
      await cubit.close();
    },
  );

  for (final pendingSource in [false, true]) {
    test(
      'close cancels pending ${pendingSource ? 'source' : 'metadata'} autoplay',
      () async {
        final metadata = Completer<Map<String, VerseTiming>>();
        final player = TestAudioPlayer();
        if (pendingSource) player.pendingLoad = Completer<Duration?>();
        final cubit = build(
          player,
          loader: (_) => pendingSource
              ? Future.value({'1:1': timing(1)})
              : metadata.future,
        );
        final loading = cubit.initVerse(autoPlay: true);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.loading, isTrue);
        cubit.hide();
        if (pendingSource) {
          player.pendingLoad!.complete(const Duration(seconds: 10));
        } else {
          metadata.complete({'1:1': timing(1)});
        }
        await loading;
        expect(player.playing, isFalse);
        expect(cubit.hasAudioSession, isFalse);
        expect(cubit.currnetVerse, isNull);
        expect(cubit.state.showed, isFalse);
        expect(cubit.state.loading, isFalse);
        await cubit.close();
      },
    );
  }

  for (final landscape in [false, true]) {
    testWidgets(
      '${landscape ? 'landscape' : 'portrait'} close button stops audio',
      (tester) async {
        tester.view.physicalSize = landscape
            ? const Size(1600, 900)
            : const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final player = TestAudioPlayer();
        final cubit = build(player);
        await tester.runAsync(() => cubit.initVerse(autoPlay: true));
        cubit.showPlayer();
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(800, 1200),
            builder: (_, _) => MaterialApp(
              home: BlocProvider.value(
                value: cubit,
                child: const Scaffold(body: Center(child: VersePlayer())),
              ),
            ),
          ),
        );
        expect(
          find.byType(landscape ? LandscapeVersePlayer : PortraitVersePlayer),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('إيقاف التلاوة وإغلاق المشغل'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(player.playing, isFalse);
        expect(cubit.hasAudioSession, isFalse);
        expect(cubit.state.showed, isFalse);
        expect(cubit.currnetVerse, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(cubit.close);
      },
    );
  }

  test(
    'bundled Nufais recording metadata contains the correct per-ayah source',
    () async {
      final data = await rootBundle.load(
        'assets/data/reciters_timing/ayah-recitation-alnufais.json.zip',
      );
      final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List());
      final file = archive.files.firstWhere((f) => f.name.endsWith('.json'));
      final json =
          jsonDecode(utf8.decode(file.content as List<int>))
              as Map<String, dynamic>;
      final first = VerseTiming.fromJson(
        '1:1',
        json['1:1'] as Map<String, dynamic>,
      );
      expect(
        first.audioUrl,
        'https://audio-cdn.tarteel.ai/quran/alnufais/001001.mp3',
      );
      expect(first.segments.first.wordIndex, 1);
      expect(first.segments.first.startMs, 0);
      expect(first.segments.first.endMs, 500);
      expect(json.containsKey('114:6'), isTrue);
    },
  );

  test(
    'paired surah metadata clips the exact ayah and highlights relative to the clip',
    () async {
      final player = TestAudioPlayer();
      final model = ReciterAudioModel(
        id: 'paired_test',
        name: 'paired',
        style: 'مرتل',
        folderName: 'paired-test',
        everyAyahFolder: 'EveryAyah',
        hasSegments: true,
        segmentsFileName: 'segments.json',
      );
      final cubit = VersePlayerCubit(
        audioPlayer: player,
        surahLoader: (_) async => (
          <int, SurahAudioItem>{
            1: SurahAudioItem(
              surahNumber: 1,
              audioUrl: 'https://example.test/surah.mp3',
              durationSec: 0,
            ),
          },
          <String, VerseTiming>{
            '1:1': VerseTiming(
              surahNumber: 1,
              verseNumber: 1,
              timestampFrom: 1000,
              timestampTo: 3000,
              durationMs: 2000,
              segments: [WordSegment(wordIndex: 1, startMs: 1200, endMs: 1500)],
            ),
          },
        ),
        autoHideDelay: const Duration(milliseconds: 20),
      );
      cubit.selectReciter(model);
      cubit.setVerse(
        surahNumber: 1,
        verseNumber: 1,
        fontFamily: 'UthmanicHafs',
        verse: 'بسم الله',
      );
      await cubit.initVerse(autoPlay: true);
      final source = player.source as ClippingAudioSource;
      expect(source.child.uri.toString(), 'https://example.test/surah.mp3');
      expect(source.start, const Duration(milliseconds: 1000));
      expect(source.end, const Duration(milliseconds: 3000));
      player.sendPosition(250);
      expect(cubit.state.activeWordIndex, 1);
      await cubit.close();
    },
  );

  test(
    'invalid paired bounds fall back without attaching paired timing',
    () async {
      final player = TestAudioPlayer();
      final model = ReciterAudioModel(
        id: 'paired_invalid',
        name: 'paired',
        style: 'مرتل',
        folderName: 'paired-invalid',
        everyAyahFolder: 'EveryAyah',
        hasSegments: true,
        segmentsFileName: 'segments.json',
      );
      final cubit = VersePlayerCubit(
        audioPlayer: player,
        surahLoader: (_) async => (
          <int, SurahAudioItem>{
            1: SurahAudioItem(
              surahNumber: 1,
              audioUrl: 'https://example.test/surah.mp3',
              durationSec: 0,
            ),
          },
          <String, VerseTiming>{
            '1:1': VerseTiming(
              surahNumber: 1,
              verseNumber: 1,
              timestampFrom: 3000,
              timestampTo: 1000,
              durationMs: 0,
              segments: [WordSegment(wordIndex: 1, startMs: 0, endMs: 500)],
            ),
          },
        ),
      );
      cubit.selectReciter(model);
      cubit.setVerse(
        surahNumber: 1,
        verseNumber: 1,
        fontFamily: 'UthmanicHafs',
        verse: 'بسم الله',
      );
      await cubit.initVerse();
      expect(player.source, isA<UriAudioSource>());
      await cubit.close();
    },
  );

  for (final matchesRecording in [true, false]) {
    test(
      'asynchronous timing requires exact recording match: $matchesRecording',
      () async {
        final player = TestAudioPlayer();
        final metadata = Completer<Map<String, VerseTiming>>();
        final model = ReciterAudioModel(
          id: 'recording_match_$matchesRecording',
          name: 'Fixture',
          style: 'مرتل',
          folderName: 'fixture-recording',
          everyAyahFolder: 'FixtureRecording',
          hasSegments: true,
        );
        final cubit = VersePlayerCubit(
          audioPlayer: player,
          timingLoader: (_) => metadata.future,
        );
        cubit.selectReciter(model);
        cubit.setVerse(
          surahNumber: 1,
          verseNumber: 1,
          fontFamily: 'UthmanicHafs',
          verse: 'بسم الله',
        );
        await cubit.initVerse();
        final playingUrl = (player.source as UriAudioSource).uri.toString();
        metadata.complete({
          '1:1': VerseTiming(
            surahNumber: 1,
            verseNumber: 1,
            audioUrl: matchesRecording
                ? playingUrl
                : '$playingUrl?different_take=1',
            timestampFrom: 0,
            timestampTo: 1000,
            durationMs: 1000,
            segments: [WordSegment(wordIndex: 1, startMs: 100, endMs: 500)],
          ),
        });
        await Future<void>.delayed(Duration.zero);
        player.sendPosition(250);
        expect(cubit.state.activeWordIndex, matchesRecording ? 1 : null);
        await cubit.close();
      },
    );
  }

  test(
    'continuous completion advances once and never reopens manually hidden controls',
    () async {
      final player = TestAudioPlayer();
      final cubit = build(player);
      cubit.toggleAutoPlayNext();
      await cubit.initVerse(autoPlay: true);
      cubit.hideUiOnly();
      player.sendState(ProcessingState.completed);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.currnetVerse!.verseNumber, 2);
      expect(player.playing, isTrue);
      expect(cubit.state.showed, isFalse);
      expect(cubit.state.loading, isFalse);
      await cubit.close();
    },
  );
}
