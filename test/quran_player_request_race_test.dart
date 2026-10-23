import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayer implements AudioPlayer {
  final loaded = <int>[];
  final neverEndingPlayback = Completer<void>();
  int playCalls = 0;
  bool failNextLoad = false;
  bool disposed = false;
  bool _playing = false;

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  bool get playing => _playing;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Duration get position => Duration.zero;
  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    if (disposed) throw StateError('Disposed player used');
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('Synthetic load failure');
    }
    final uri = (source as UriAudioSource).uri;
    loaded.add(int.parse(uri.pathSegments.last.split('.').first));
    return const Duration(minutes: 10);
  }

  @override
  Future<void> play() {
    if (disposed) throw StateError('Disposed player used');
    playCalls++;
    _playing = true;
    // Real just_audio.play() can remain pending until the recitation finishes.
    return neverEndingPlayback.future;
  }

  @override
  Future<void> stop() async {
    _playing = false;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _playing = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCubit extends QuranPlayerCubit {
  _TestCubit(_FakePlayer player, {this.resolve}) : super(audioPlayer: player);
  final Future<String> Function(int)? resolve;
  @override
  Future<String> getSurahUrl(int surahNum) =>
      resolve?.call(surahNum) ??
      Future.value('https://example.invalid/$surahNum.mp3');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePlayer player;
  late _TestCubit cubit;
  const deadline = Duration(seconds: 2);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    player = _FakePlayer();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test(
    'a new surah never waits for the previous playback future to complete',
    () async {
      cubit = _TestCubit(player);
      await cubit.playSurah(1).timeout(deadline);
      expect(player.neverEndingPlayback.isCompleted, isFalse);
      await cubit.playSurah(2).timeout(deadline);
      expect(player.loaded, [1, 2]);
      expect(player.playCalls, 2);
      expect(cubit.selectedSurah, 2);
    },
  );

  test(
    'a slow earlier request cannot set or play its source after a newer request',
    () async {
      final gate = Completer<String>();
      cubit = _TestCubit(
        player,
        resolve: (surah) => surah == 1
            ? gate.future
            : Future.value('https://example.invalid/$surah.mp3'),
      );
      final first = cubit.playSurah(1);
      await Future<void>.delayed(Duration.zero);
      final second = cubit.playSurah(2);
      gate.complete('https://example.invalid/1.mp3');
      await Future.wait([first, second]).timeout(deadline);
      expect(player.loaded, [2]);
      expect(player.playCalls, 1);
    },
  );

  test(
    'requesting the same surah during a canceled load still loads a valid source',
    () async {
      final gate = Completer<String>();
      var requests = 0;
      cubit = _TestCubit(
        player,
        resolve: (surah) => ++requests == 1
            ? gate.future
            : Future.value('https://example.invalid/$surah.mp3'),
      );
      final first = cubit.playSurah(1);
      await Future<void>.delayed(Duration.zero);
      final second = cubit.playSurah(1);
      gate.complete('https://example.invalid/1.mp3');
      await Future.wait([first, second]).timeout(deadline);
      expect(player.loaded, [1]);
      expect(player.playCalls, 1);
    },
  );

  test('a failed source does not poison later playback requests', () async {
    cubit = _TestCubit(player);
    player.failNextLoad = true;
    await cubit.playSurah(1).timeout(deadline);
    expect(player.playCalls, 0);
    await cubit.playSurah(2).timeout(deadline);
    expect(player.loaded, [2]);
    expect(player.playCalls, 1);
  });

  test('closing during URL loading prevents late player operations', () async {
    final gate = Completer<String>();
    cubit = _TestCubit(player, resolve: (_) => gate.future);
    final request = cubit.playSurah(1);
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete('https://example.invalid/1.mp3');
    await request.timeout(deadline);
    expect(player.disposed, isTrue);
    expect(player.loaded, isEmpty);
    expect(player.playCalls, 0);
  });

  test('direct init and play requests share source serialization', () async {
    final gate = Completer<String>();
    cubit = _TestCubit(
      player,
      resolve: (surah) => surah == 1
          ? gate.future
          : Future.value('https://example.invalid/$surah.mp3'),
    );
    final initial = cubit.init(1);
    await Future<void>.delayed(Duration.zero);
    final play = cubit.playSurah(2);
    gate.complete('https://example.invalid/1.mp3');
    expect(await initial.timeout(deadline), isFalse);
    await play.timeout(deadline);
    expect(player.loaded, [2]);
    expect(player.playCalls, 1);
  });
}
