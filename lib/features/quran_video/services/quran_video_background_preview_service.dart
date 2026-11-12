import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class QuranVideoBackgroundPreviewService {
  const QuranVideoBackgroundPreviewService();

  static const Duration _startupTimeout = Duration(seconds: 15);
  static const Duration _completionTimeout = Duration(seconds: 45);

  Future<String> createVideoThumbnail(String videoPath) async {
    final stopwatch = Stopwatch()..start();
    final operationId = DateTime.now().microsecondsSinceEpoch.toString();
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      AppLogger.logEvent('QuranVideo', 'preview_failed', {
        'operation_id': operationId,
        'reason': 'background_file_missing',
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      throw const QuranVideoPreviewException();
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final previewDirectory = Directory(
      p.join(temporaryDirectory.path, 'quran_video_previews'),
    );
    await previewDirectory.create(recursive: true);
    final stat = await videoFile.stat();
    final cacheKey =
        '${videoPath.hashCode.abs()}_${stat.size}_${stat.modified.microsecondsSinceEpoch}';
    final thumbnail = File(
      p.join(previewDirectory.path, 'background_$cacheKey.jpg'),
    );
    if (await thumbnail.exists() && await thumbnail.length() > 0) {
      AppLogger.logEvent('QuranVideo', 'preview_cache_hit', {
        'operation_id': operationId,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return thumbnail.path;
    }

    var attemptNumber = 0;
    for (final seekSeconds in <String?>[null, '0.25']) {
      attemptNumber++;
      if (await thumbnail.exists()) await thumbnail.delete();
      final attemptStopwatch = Stopwatch()..start();
      AppLogger.logEvent('QuranVideo', 'preview_attempt_started', {
        'operation_id': operationId,
        'attempt': attemptNumber,
        'seek_variant': seekSeconds == null ? 'default' : 'fallback',
        'startup_timeout_ms': _startupTimeout.inMilliseconds,
        'completion_timeout_ms': _completionTimeout.inMilliseconds,
      });
      late final FFmpegSession session;
      try {
        session = await _runPreviewAttempt(
          buildThumbnailArguments(
            videoPath: videoPath,
            thumbnailPath: thumbnail.path,
            seekSeconds: seekSeconds,
          ),
        );
      } catch (error) {
        AppLogger.logEvent('QuranVideo', 'preview_attempt_failed', {
          'operation_id': operationId,
          'attempt': attemptNumber,
          'reason': error is TimeoutException
              ? 'timeout'
              : 'exception_${error.runtimeType}',
          'elapsed_ms': attemptStopwatch.elapsedMilliseconds,
        });
        continue;
      }
      if (ReturnCode.isSuccess(await session.getReturnCode()) &&
          await thumbnail.exists() &&
          await thumbnail.length() > 0) {
        AppLogger.logEvent('QuranVideo', 'preview_finished', {
          'operation_id': operationId,
          'outcome': 'success',
          'attempt': attemptNumber,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
        return thumbnail.path;
      }
      AppLogger.logEvent('QuranVideo', 'preview_attempt_failed', {
        'operation_id': operationId,
        'attempt': attemptNumber,
        'reason': 'return_code_or_empty_thumbnail',
        'return_code': (await session.getReturnCode())?.getValue(),
        'elapsed_ms': attemptStopwatch.elapsedMilliseconds,
      });
    }

    AppLogger.logEvent('QuranVideo', 'preview_failed', {
      'operation_id': operationId,
      'reason': 'all_preview_attempts_failed',
      'elapsed_ms': stopwatch.elapsedMilliseconds,
    });
    throw const QuranVideoPreviewException();
  }

  Future<FFmpegSession> _runPreviewAttempt(List<String> arguments) async {
    final completion = Completer<FFmpegSession>();
    final startFuture = FFmpegKit.executeWithArgumentsAsync(arguments, (
      session,
    ) {
      if (!completion.isCompleted) completion.complete(session);
    });
    late final FFmpegSession startedSession;
    try {
      startedSession = await startFuture.timeout(_startupTimeout);
    } on TimeoutException {
      unawaited(
        startFuture
            .then((session) async {
              try {
                await FFmpegKit.cancel(session.getSessionId());
              } catch (_) {}
            })
            .catchError((Object _) {}),
      );
      rethrow;
    }
    try {
      return await completion.future.timeout(_completionTimeout);
    } on TimeoutException {
      try {
        await FFmpegKit.cancel(startedSession.getSessionId());
      } catch (_) {}
      rethrow;
    }
  }

  static List<String> buildThumbnailArguments({
    required String videoPath,
    required String thumbnailPath,
    String? seekSeconds,
  }) => [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    if (seekSeconds != null) ...['-ss', seekSeconds],
    '-i',
    videoPath,
    '-frames:v',
    '1',
    '-vf',
    'scale=1280:1280:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1',
    '-q:v',
    '2',
    '-update',
    '1',
    thumbnailPath,
  ];
}

class QuranVideoPreviewException implements Exception {
  const QuranVideoPreviewException();
}
