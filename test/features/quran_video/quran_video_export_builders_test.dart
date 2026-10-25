import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_ass_builder.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_command_builder.dart';

void main() {
  group('QuranVideoAssBuilder', () {
    test('writes Arabic subtitles with the selected size and position', () {
      const options = QuranVideoExportOptions(
        aspectRatio: QuranVideoAspectRatio.portrait,
        resolution: QuranVideoResolution.hd720,
        position: 0.75,
      );
      final script = QuranVideoAssBuilder.build(
        cues: const [
          QuranVideoSubtitleCue(
            startMs: 10,
            endMs: 1250,
            words: ['بِسْمِ', 'اللَّهِ'],
          ),
        ],
        options: options,
      );

      expect(script, contains('PlayResX: 720'));
      expect(script, contains('PlayResY: 1280'));
      expect(script, contains('Style: Default,Amiri Quran'));
      expect(script, contains(r'\pos(360,960)'));
      expect(script, contains('0:00:00.01,0:00:01.25'));
      expect(script, contains('بِسْمِ اللَّهِ'));
    });

    test('word highlight and reveal use the one-based word timing index', () {
      const highlightOptions = QuranVideoExportOptions(
        displayMode: QuranVideoDisplayMode.wordHighlight,
      );
      final highlighted = QuranVideoAssBuilder.build(
        cues: const [
          QuranVideoSubtitleCue(
            startMs: 0,
            endMs: 900,
            words: ['الرَّحْمَٰنِ', 'الرَّحِيمِ'],
            highlightedWordIndex: 2,
          ),
        ],
        options: highlightOptions,
      );
      expect(highlighted, contains('الرَّحْمَٰنِ'));
      expect(highlighted, contains(r'{\1c&H004FD5FF&}الرَّحِيمِ'));

      final revealed = QuranVideoAssBuilder.build(
        cues: const [
          QuranVideoSubtitleCue(
            startMs: 0,
            endMs: 400,
            words: ['الرَّحْمَٰنِ', 'الرَّحِيمِ'],
            highlightedWordIndex: 2,
          ),
        ],
        options: highlightOptions.copyWith(
          displayMode: QuranVideoDisplayMode.wordReveal,
        ),
      );
      expect(revealed, contains('الرَّحِيمِ'));
      expect(revealed, isNot(contains('الرَّحْمَٰنِ')));
    });

    test('skips word-reveal cues without a valid word index', () {
      final script = QuranVideoAssBuilder.build(
        cues: const [
          QuranVideoSubtitleCue(startMs: 0, endMs: 400, words: ['آية']),
        ],
        options: const QuranVideoExportOptions(
          displayMode: QuranVideoDisplayMode.wordReveal,
        ),
      );
      expect(script, isNot(contains('Dialogue:')));
    });
  });

  group('QuranVideoCommandBuilder', () {
    test(
      'maps Quran audio and filtered video only, never source-video audio',
      () {
        final args = QuranVideoCommandBuilder.build(
          audioKind: QuranVideoAudioKind.concatenatedVerses,
          audioInput: '/tmp/audio.ffconcat',
          audioClipStartMs: 0,
          audioClipEndMs: 5000,
          backgroundType: QuranVideoBackgroundType.video,
          backgroundPath: '/tmp/background.mp4',
          subtitlePath: '/tmp/captions.ass',
          fontDirectory: '/tmp/fonts',
          outputPath: '/tmp/output.mp4',
          videoEncoder: 'h264_mediacodec',
          options: const QuranVideoExportOptions(),
        );

        expect(args, containsAllInOrder(['-f', 'concat', '-safe', '0']));
        expect(args, containsAllInOrder(['-stream_loop', '-1', '-i']));
        expect(args, containsAllInOrder(['-map', '[v]', '-map', '[a]']));
        expect(args, contains('h264_mediacodec'));
        expect(args, contains('aac'));
        expect(args, contains('+faststart'));
        expect(args, isNot(contains('1:a:0')));
        expect(args, isNot(contains('-map 1:a')));
        expect(args.join(' '), contains("ass=filename='/tmp/captions.ass'"));
        expect(args.last, '/tmp/output.mp4');
      },
    );

    test('trims a full-surah source to the selected synchronized range', () {
      final args = QuranVideoCommandBuilder.build(
        audioKind: QuranVideoAudioKind.fullSurah,
        audioInput: 'https://example.org/recitation.mp3',
        audioClipStartMs: 1234,
        audioClipEndMs: 5678,
        backgroundType: QuranVideoBackgroundType.image,
        backgroundPath: '/tmp/background.jpg',
        subtitlePath: '/tmp/captions.ass',
        fontDirectory: '/tmp/fonts',
        outputPath: '/tmp/output.mp4',
        videoEncoder: 'h264_videotoolbox',
        options: const QuranVideoExportOptions(
          aspectRatio: QuranVideoAspectRatio.landscape,
          resolution: QuranVideoResolution.hd720,
        ),
      );
      final filterGraph = args[args.indexOf('-filter_complex') + 1];

      expect(args, contains('h264_videotoolbox'));
      expect(args, containsAllInOrder(['-loop', '1', '-framerate', '30']));
      expect(filterGraph, contains('atrim=start=1.234:end=5.678'));
      expect(filterGraph, contains('scale=1280:720'));
      expect(filterGraph, isNot(contains('aresample')));
      expect(args, contains('2400k'));
    });
  });
}
