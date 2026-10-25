import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';

class QuranVideoCommandBuilder {
  const QuranVideoCommandBuilder._();

  static List<String> build({
    required QuranVideoAudioKind audioKind,
    required String audioInput,
    required int audioClipStartMs,
    required int audioClipEndMs,
    required QuranVideoBackgroundType backgroundType,
    required String backgroundPath,
    required String subtitlePath,
    required String fontDirectory,
    required String outputPath,
    required String videoEncoder,
    required QuranVideoExportOptions options,
  }) {
    final width = options.width;
    final height = options.height;
    final arguments = <String>['-y', '-hide_banner', '-loglevel', 'error'];

    if (audioKind == QuranVideoAudioKind.concatenatedVerses) {
      arguments.addAll(['-f', 'concat', '-safe', '0', '-i', audioInput]);
    } else {
      final inputUri = Uri.tryParse(audioInput);
      if (inputUri != null && inputUri.scheme == 'https') {
        arguments.addAll([
          '-rw_timeout',
          '20000000',
          '-reconnect',
          '1',
          '-reconnect_streamed',
          '1',
          '-reconnect_delay_max',
          '5',
        ]);
      }
      arguments.addAll(['-i', audioInput]);
    }

    if (backgroundType == QuranVideoBackgroundType.image) {
      arguments.addAll([
        '-loop',
        '1',
        '-framerate',
        '30',
        '-i',
        backgroundPath,
      ]);
    } else {
      // The source video is looped to cover the full recitation. Its audio
      // stream is intentionally never mapped into the output.
      arguments.addAll(['-stream_loop', '-1', '-i', backgroundPath]);
    }

    final subtitleFilter =
        "ass=filename='${_escapeFilterValue(subtitlePath)}':fontsdir='${_escapeFilterValue(fontDirectory)}'";
    final videoFilter =
        '[1:v:0]scale=$width:$height:force_original_aspect_ratio=increase:flags=lanczos,'
        'crop=$width:$height,setsar=1,fps=30,$subtitleFilter[v]';
    final audioFilter = audioKind == QuranVideoAudioKind.concatenatedVerses
        ? '[0:a:0]aresample=48000:async=1:first_pts=0,asetpts=PTS-STARTPTS[a]'
        : '[0:a:0]atrim=start=${_seconds(audioClipStartMs)}:end=${_seconds(audioClipEndMs)},'
              'asetpts=PTS-STARTPTS[a]';

    arguments.addAll([
      '-filter_complex',
      '$audioFilter;$videoFilter',
      '-map',
      '[v]',
      '-map',
      '[a]',
      '-c:v',
      videoEncoder,
      '-b:v',
      '${options.videoBitrateKbps}k',
      '-g',
      '60',
      '-pix_fmt',
      'yuv420p',
      '-r',
      '30',
      '-tag:v',
      'avc1',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-ar',
      '48000',
      '-ac',
      '2',
      '-movflags',
      '+faststart',
      '-shortest',
      outputPath,
    ]);
    return arguments;
  }

  static String _seconds(int milliseconds) =>
      (milliseconds / 1000).toStringAsFixed(3);

  static String _escapeFilterValue(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll(',', r'\,')
      .replaceAll("'", r"\'")
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');
}
