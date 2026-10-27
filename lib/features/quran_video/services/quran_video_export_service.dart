import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/log.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/statistics.dart';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/helpers/background_resource_download_service.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_ass_builder.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_command_builder.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;

class QuranVideoExportProgress {
  const QuranVideoExportProgress({
    required this.fraction,
    required this.message,
  });

  final double fraction;
  final String message;
}

typedef QuranVideoProgressCallback =
    void Function(QuranVideoExportProgress progress);

class QuranVideoExportResult {
  const QuranVideoExportResult({
    required this.path,
    required this.durationMs,
    required this.fileSizeBytes,
  });

  final String path;
  final int durationMs;
  final int fileSizeBytes;
}

class QuranVideoExportException implements Exception {
  const QuranVideoExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _EncoderAttempt {
  const _EncoderAttempt({required this.session, this.timedOut = false});

  final FFmpegSession session;
  final bool timedOut;
}

class _PreparedVerseAudio {
  const _PreparedVerseAudio({
    required this.verseNumber,
    required this.durationMs,
    this.timing,
  });

  final int verseNumber;
  final int durationMs;
  final VerseTiming? timing;
}

class _PreparedAudioTrack {
  const _PreparedAudioTrack({
    required this.kind,
    required this.input,
    required this.durationMs,
    required this.verses,
    this.clipStartMs = 0,
    this.clipEndMs = 0,
  });

  final QuranVideoAudioKind kind;
  final String input;
  final int durationMs;
  final List<_PreparedVerseAudio> verses;
  final int clipStartMs;
  final int clipEndMs;
}

class QuranVideoExportService {
  QuranVideoExportService();

  static const Duration _encoderStartupTimeout = Duration(seconds: 20);

  int? _activeSessionId;
  String? _activeResourceDownloadId;
  bool _isExporting = false;
  bool _cancelRequested = false;
  final Set<String> _stagedAudioPaths = {};

  Future<QuranVideoExportResult> export({
    required ReciterAudioModel reciter,
    required int surahNumber,
    required int fromVerse,
    required int toVerse,
    required String backgroundPath,
    required QuranVideoBackgroundType backgroundType,
    required QuranVideoExportOptions options,
    required QuranVideoProgressCallback onProgress,
  }) async {
    if (_isExporting) {
      throw const QuranVideoExportException('يوجد تصدير آخر قيد التنفيذ.');
    }
    _isExporting = true;
    _cancelRequested = false;
    _stagedAudioPaths.clear();
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final operationId = startedAt.microsecondsSinceEpoch.toString();
    Directory? workDirectory;
    String? outputPath;
    var audioKind = 'unresolved';
    var completedSuccessfully = false;
    var failureLogged = false;

    try {
      _validateRequest(surahNumber, fromVerse, toVerse, backgroundPath);
      AppLogger.logEvent('QuranVideo', 'export_started', {
        'operation_id': operationId,
        'trigger': 'user_request',
        'started_at': startedAt.toIso8601String(),
        'surah': surahNumber,
        'from_ayah': fromVerse,
        'to_ayah': toVerse,
        'reader_id': reciter.id,
        'display_mode': options.displayMode.name,
        'background_type': backgroundType.name,
        'width': options.width,
        'height': options.height,
      });
      onProgress(
        const QuranVideoExportProgress(
          fraction: 0.03,
          message: 'جارٍ تجهيز بيانات التلاوة…',
        ),
      );
      onProgress(
        const QuranVideoExportProgress(
          fraction: 0.04,
          message: 'جارٍ قراءة توقيت الآيات لهذا القارئ…',
        ),
      );
      final temporaryDirectory = await getTemporaryDirectory();
      workDirectory = Directory(
        p.join(
          temporaryDirectory.path,
          'quran_video_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await workDirectory.create(recursive: true);

      final track = await _prepareAudioTrack(
        reciter: reciter,
        surahNumber: surahNumber,
        fromVerse: fromVerse,
        toVerse: toVerse,
        workDirectory: workDirectory,
        options: options,
        onProgress: onProgress,
      );
      audioKind = track.kind.name;
      AppLogger.logEvent('QuranVideo', 'audio_prepared', {
        'operation_id': operationId,
        'reader_id': reciter.id,
        'audio_kind': audioKind,
        'duration_ms': track.durationMs,
        'verse_count': track.verses.length,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      _checkCancelled();

      final cues = _buildSubtitleCues(
        track: track,
        surahNumber: surahNumber,
        displayMode: options.displayMode,
      );
      if (cues.isEmpty) {
        throw const QuranVideoExportException(
          'لم أجد توقيتًا صالحًا لعرض الآيات لهذا القارئ. جرّب قارئًا آخر أو غيّر طريقة العرض إلى آية بآية.',
        );
      }
      final subtitleFile = File(p.join(workDirectory.path, 'captions.ass'));
      await subtitleFile.writeAsString(
        QuranVideoAssBuilder.build(cues: cues, options: options),
        encoding: utf8,
        flush: true,
      );

      final fontDirectory = Directory(p.join(workDirectory.path, 'fonts'));
      await fontDirectory.create(recursive: true);
      final fontData = await rootBundle.load(
        'assets/fonts/AmiriQuran-Regular.ttf',
      );
      await File(
        p.join(fontDirectory.path, 'AmiriQuran-Regular.ttf'),
      ).writeAsBytes(fontData.buffer.asUint8List(), flush: true);
      await FFmpegKitConfig.setFontDirectoryList([fontDirectory.path]);

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final outputDirectory = Directory(
        p.join(documentsDirectory.path, 'quran_videos'),
      );
      await outputDirectory.create(recursive: true);
      outputPath = p.join(
        outputDirectory.path,
        'quran_${surahNumber}_$fromVerse-$toVerse-${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      onProgress(
        const QuranVideoExportProgress(
          fraction: 0.38,
          message: 'جارٍ إنشاء الفيديو ومزامنة الآيات…',
        ),
      );

      final encoders = <String>[_videoEncoderForCurrentPlatform(), 'libx264'];
      _EncoderAttempt? successfulAttempt;
      var usedEncoder = encoders.first;
      for (var index = 0; index < encoders.length; index++) {
        final encoder = encoders[index];
        usedEncoder = encoder;
        final arguments = QuranVideoCommandBuilder.build(
          audioKind: track.kind,
          audioInput: track.input,
          audioClipStartMs: track.clipStartMs,
          audioClipEndMs: track.clipEndMs,
          backgroundType: backgroundType,
          backgroundPath: backgroundPath,
          subtitlePath: subtitleFile.path,
          fontDirectory: fontDirectory.path,
          outputPath: outputPath,
          videoEncoder: encoder,
          options: options,
        );
        AppLogger.logEvent('QuranVideo', 'encoding_started', {
          'operation_id': operationId,
          'encoder': encoder,
          'duration_ms': track.durationMs,
        });
        final attempt = await _runEncoderAttempt(
          arguments: arguments,
          durationMs: track.durationMs,
          onProgress: onProgress,
        );
        _checkCancelled();
        final returnCode = await attempt.session.getReturnCode();
        if (!attempt.timedOut && ReturnCode.isSuccess(returnCode)) {
          successfulAttempt = attempt;
          break;
        }
        if (!attempt.timedOut &&
            (ReturnCode.isCancel(returnCode) || _cancelRequested)) {
          throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
        }
        AppLogger.logEvent('QuranVideo', 'encoding_attempt_failed', {
          'operation_id': operationId,
          'encoder': encoder,
          'reason': attempt.timedOut ? 'timeout' : 'return_code',
          'return_code': returnCode?.getValue(),
        });
        if (index + 1 < encoders.length) {
          AppLogger.logEvent('QuranVideo', 'encoding_fallback_started', {
            'operation_id': operationId,
            'from_encoder': encoder,
            'to_encoder': encoders[index + 1],
          });
          onProgress(
            const QuranVideoExportProgress(
              fraction: 0.38,
              message: 'محرك الترميز لم يستجب؛ جارٍ استخدام محرك بديل…',
            ),
          );
        }
      }

      if (successfulAttempt == null) {
        AppLogger.logEvent('QuranVideo', 'export_failed', {
          'operation_id': operationId,
          'reason': 'all_video_encoders_failed',
          'encoder': usedEncoder,
          'reader_id': reciter.id,
          'finished_at': DateTime.now().toIso8601String(),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
        failureLogged = true;
        throw const QuranVideoExportException(
          'تعذر إنشاء الفيديو. تحقق من مساحة التخزين، ثم حاول مرة أخرى.',
        );
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists() || await outputFile.length() == 0) {
        throw const QuranVideoExportException(
          'انتهى التصدير دون إنشاء ملف فيديو صالح. حاول مرة أخرى.',
        );
      }
      final fileSizeBytes = await outputFile.length();
      AppLogger.logEvent('QuranVideo', 'export_finished', {
        'operation_id': operationId,
        'reader_id': reciter.id,
        'surah': surahNumber,
        'duration_ms': track.durationMs,
        'file_size_bytes': fileSizeBytes,
        'width': options.width,
        'height': options.height,
        'finished_at': DateTime.now().toIso8601String(),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      onProgress(
        const QuranVideoExportProgress(
          fraction: 1,
          message: 'اكتمل إنشاء الفيديو',
        ),
      );
      completedSuccessfully = true;
      return QuranVideoExportResult(
        path: outputPath,
        durationMs: track.durationMs,
        fileSizeBytes: fileSizeBytes,
      );
    } on BackgroundResourceDownloadException catch (error) {
      if (error.wasCancelled || _cancelRequested) {
        throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
      }
      AppLogger.logEvent('QuranVideo', 'export_failed', {
        'operation_id': operationId,
        'reason': 'audio_download_failed',
        'reader_id': reciter.id,
        'finished_at': DateTime.now().toIso8601String(),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      failureLogged = true;
      throw const QuranVideoExportException(
        'تعذر تنزيل التلاوة. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
      );
    } on QuranVideoExportException catch (error) {
      if (error.message == 'تم إلغاء إنشاء الفيديو.') {
        AppLogger.logEvent('QuranVideo', 'export_cancelled', {
          'operation_id': operationId,
          'reader_id': reciter.id,
          'finished_at': DateTime.now().toIso8601String(),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      } else if (!failureLogged) {
        AppLogger.logEvent('QuranVideo', 'export_failed', {
          'operation_id': operationId,
          'reason': 'validation_or_metadata_unavailable',
          'reader_id': reciter.id,
          'audio_kind': audioKind,
          'finished_at': DateTime.now().toIso8601String(),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      }
      rethrow;
    } catch (error) {
      AppLogger.logEvent('QuranVideo', 'export_failed', {
        'operation_id': operationId,
        'reason': error.runtimeType.toString(),
        'reader_id': reciter.id,
        'audio_kind': audioKind,
        'finished_at': DateTime.now().toIso8601String(),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      failureLogged = true;
      if (_cancelRequested) {
        throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
      }
      throw const QuranVideoExportException(
        'حدث خطأ أثناء إنشاء الفيديو. راجع اتصال الإنترنت والمساحة المتاحة وحاول مرة أخرى.',
      );
    } finally {
      stopwatch.stop();
      _activeSessionId = null;
      _activeResourceDownloadId = null;
      _isExporting = false;
      if (workDirectory != null && await workDirectory.exists()) {
        try {
          await workDirectory.delete(recursive: true);
        } catch (_) {
          // Temporary export material is best-effort cleanup only.
        }
      }
      for (final audioPath in _stagedAudioPaths.toList()) {
        try {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) await audioFile.delete();
        } catch (_) {
          // Staged recitation clips are temporary and best-effort cleanup.
        }
      }
      _stagedAudioPaths.clear();
      if (!completedSuccessfully && outputPath != null) {
        try {
          final outputFile = File(outputPath);
          if (await outputFile.exists()) await outputFile.delete();
        } catch (_) {
          // A cancelled partial export should not be exposed as a result.
        }
      }
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final downloadId = _activeResourceDownloadId;
    if (downloadId != null) {
      try {
        await BackgroundResourceDownloadService.instance.cancel(downloadId);
      } catch (_) {
        // Cancellation remains best-effort if the native task has finished.
      }
    }
    final sessionId = _activeSessionId;
    if (sessionId != null) {
      try {
        await FFmpegKit.cancel(sessionId);
      } catch (_) {
        // Cancellation remains best-effort if the native session has finished.
      }
    }
  }

  Future<_EncoderAttempt> _runEncoderAttempt({
    required List<String> arguments,
    required int durationMs,
    required QuranVideoProgressCallback onProgress,
  }) async {
    final completion = Completer<FFmpegSession>();
    final startFuture = FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (completedSession) {
        if (!completion.isCompleted) completion.complete(completedSession);
      },
      (Log _) {
        // FFmpeg logs may contain private local paths or source URLs.
      },
      (Statistics statistics) {
        final fraction = durationMs <= 0
            ? 0.65
            : (statistics.getTime() / durationMs).clamp(0.0, 1.0);
        onProgress(
          QuranVideoExportProgress(
            fraction: 0.38 + fraction * 0.58,
            message: 'جارٍ ترميز الفيديو…',
          ),
        );
      },
    );
    late final FFmpegSession session;
    try {
      session = await startFuture.timeout(_encoderStartupTimeout);
    } on TimeoutException {
      unawaited(
        startFuture
            .then((lateSession) async {
              try {
                await FFmpegKit.cancel(lateSession.getSessionId());
              } catch (_) {
                // A late session must not continue consuming resources.
              }
            })
            .catchError((Object _) {}),
      );
      if (_cancelRequested) {
        throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
      }
      throw const QuranVideoExportException(
        'لم يستجب محرك الترميز لبدء التصدير؛ أُوقفت المحاولة.',
      );
    }
    _activeSessionId = session.getSessionId();
    if (_cancelRequested) {
      await FFmpegKit.cancel(_activeSessionId);
    }

    try {
      final completed = await completion.future.timeout(
        _encoderTimeout(durationMs),
      );
      return _EncoderAttempt(session: completed);
    } on TimeoutException {
      final sessionId = _activeSessionId;
      if (sessionId != null) {
        try {
          await FFmpegKit.cancel(sessionId);
        } catch (_) {
          // Continue waiting briefly for FFmpeg's completion callback.
        }
      }
      try {
        final stoppedSession = await completion.future.timeout(
          const Duration(seconds: 12),
        );
        return _EncoderAttempt(session: stoppedSession, timedOut: true);
      } on TimeoutException {
        if (_cancelRequested) {
          throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
        }
        throw const QuranVideoExportException(
          'توقف محرك الترميز دون استجابة؛ أُوقفت المحاولة لحماية التطبيق.',
        );
      }
    } finally {
      _activeSessionId = null;
    }
  }

  Duration _encoderTimeout(int durationMs) {
    final playbackSeconds = durationMs > 0 ? durationMs / 1000 : 0;
    final estimatedSeconds = (playbackSeconds * 3 + 20).ceil();
    return Duration(seconds: estimatedSeconds < 45 ? 45 : estimatedSeconds);
  }

  void _validateRequest(
    int surahNumber,
    int fromVerse,
    int toVerse,
    String backgroundPath,
  ) {
    if (surahNumber < 1 || surahNumber > 114) {
      throw const QuranVideoExportException('اختر سورة صحيحة.');
    }
    final verseCount = quran.getVerseCount(surahNumber);
    if (fromVerse < 1 || toVerse < fromVerse || toVerse > verseCount) {
      throw const QuranVideoExportException(
        'راجع نطاق الآيات؛ رقم البداية والنهاية يجب أن يكونا ضمن السورة.',
      );
    }
    if (!File(backgroundPath).existsSync()) {
      throw const QuranVideoExportException(
        'لم أتمكن من الوصول إلى ملف الخلفية. اختر الصورة أو الفيديو مرة أخرى.',
      );
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const QuranVideoExportException(
        'إنشاء الفيديو متاح حاليًا على أجهزة Android وiOS فقط.',
      );
    }
  }

  Future<_PreparedAudioTrack> _prepareAudioTrack({
    required ReciterAudioModel reciter,
    required int surahNumber,
    required int fromVerse,
    required int toVerse,
    required Directory workDirectory,
    required QuranVideoExportOptions options,
    required QuranVideoProgressCallback onProgress,
  }) async {
    final verseNumbers = List<int>.generate(
      toVerse - fromVerse + 1,
      (index) => fromVerse + index,
    );
    Map<String, VerseTiming> allTimings = const {};
    if (reciter.hasSegments || reciter.zipFileName != null) {
      try {
        allTimings = await ReciterAudioHelper.getSegments(
          reciter,
        ).timeout(const Duration(seconds: 45));
      } catch (_) {
        allTimings = const {};
      }
    }
    _checkCancelled();
    final verseTimings = <int, VerseTiming?>{
      for (final verse in verseNumbers)
        verse: allTimings['$surahNumber:$verse'],
    };

    if (options.displayMode != QuranVideoDisplayMode.ayahByAyah) {
      final hasWordTimings = verseNumbers.every((verse) {
        final segments = verseTimings[verse]?.segments ?? const [];
        return segments.isNotEmpty;
      });
      if (!reciter.supportsWordByWord || !hasWordTimings) {
        throw const QuranVideoExportException(
          'التظليل كلمة بكلمة غير متاح لهذا القارئ أو لهذه الآيات؛ اختر قارئًا يدعم التوقيت التفصيلي، أو اختر العرض آية بآية.',
        );
      }
    }

    final hasPerAyahAudio = verseNumbers.any(
      (verse) => (verseTimings[verse]?.audioUrl ?? '').trim().isNotEmpty,
    );
    if (hasPerAyahAudio) {
      if (!verseNumbers.every(
        (verse) => (verseTimings[verse]?.audioUrl ?? '').trim().isNotEmpty,
      )) {
        throw const QuranVideoExportException(
          'بيانات تسجيل هذا القارئ لا تحتوي روابط كاملة لكل الآيات المختارة؛ اختر نطاقًا آخر أو قارئًا آخر.',
        );
      }
      return _preparePerAyahTrack(
        reciter: reciter,
        surahNumber: surahNumber,
        verseNumbers: verseNumbers,
        verseTimings: verseTimings,
        workDirectory: workDirectory,
        onProgress: onProgress,
      );
    }

    final hasValidSurahTimings = verseNumbers.every((verse) {
      final timing = verseTimings[verse];
      return timing != null && _validVerseBounds(timing);
    });
    Map<int, SurahAudioItem> surahAudio = const {};
    if (reciter.supportsFullSurah && hasValidSurahTimings) {
      try {
        surahAudio = await ReciterAudioHelper.getSurahs(
          reciter,
        ).timeout(const Duration(seconds: 45));
      } catch (_) {
        surahAudio = const {};
      }
    }
    final fullSurahItem = surahAudio[surahNumber];
    if (fullSurahItem != null &&
        fullSurahItem.audioUrl.trim().isNotEmpty &&
        hasValidSurahTimings) {
      final firstTiming = verseTimings[fromVerse]!;
      final lastTiming = verseTimings[toVerse]!;
      final clipStartMs = firstTiming.timestampFrom;
      final clipEndMs = lastTiming.timestampTo;
      if (clipEndMs <= clipStartMs) {
        throw const QuranVideoExportException(
          'توقيت الآيات في ملف هذا القارئ غير صالح للتصدير.',
        );
      }
      var input = await _resolveAudioInput(fullSurahItem.audioUrl, reciter);
      if (!File(input).existsSync()) {
        final temporaryDirectory = await getTemporaryDirectory();
        final audioDirectory = Directory(
          p.join(
            temporaryDirectory.path,
            'quran_video_audio',
            reciter.id,
            surahNumber.toString().padLeft(3, '0'),
          ),
        );
        await audioDirectory.create(recursive: true);
        final sourceUri = Uri.tryParse(input);
        final sourceExtension = p
            .extension(sourceUri?.path ?? '')
            .toLowerCase();
        const supportedExtensions = {
          '.mp3',
          '.m4a',
          '.aac',
          '.ogg',
          '.opus',
          '.wav',
        };
        final extension = supportedExtensions.contains(sourceExtension)
            ? sourceExtension
            : '.mp3';
        final destinationPath = p.join(
          audioDirectory.path,
          'full_surah$extension',
        );
        final downloadId = 'quran-video:${reciter.id}:$surahNumber:full-surah';
        _activeResourceDownloadId = downloadId;
        try {
          input = await BackgroundResourceDownloadService.instance
              .downloadToPath(
                id: downloadId,
                url: input,
                destinationPath: destinationPath,
                displayName: 'تلاوة السورة $surahNumber',
                onProgress: (progress) => onProgress(
                  QuranVideoExportProgress(
                    fraction: 0.05 + progress * 0.29,
                    message: 'جارٍ تنزيل التلاوة…',
                  ),
                ),
              );
          _stagedAudioPaths.add(input);
        } finally {
          if (_activeResourceDownloadId == downloadId) {
            _activeResourceDownloadId = null;
          }
        }
      }
      return _PreparedAudioTrack(
        kind: QuranVideoAudioKind.fullSurah,
        input: input,
        durationMs: clipEndMs - clipStartMs,
        verses: [
          for (final verse in verseNumbers)
            _PreparedVerseAudio(
              verseNumber: verse,
              durationMs:
                  (verseTimings[verse]!.timestampTo -
                          verseTimings[verse]!.timestampFrom)
                      .clamp(1, 1 << 31)
                      .toInt(),
              timing: verseTimings[verse],
            ),
        ],
        clipStartMs: clipStartMs,
        clipEndMs: clipEndMs,
      );
    }

    if (reciter.everyAyahFolder.trim().isNotEmpty) {
      return _preparePerAyahTrack(
        reciter: reciter,
        surahNumber: surahNumber,
        verseNumbers: verseNumbers,
        verseTimings: verseTimings,
        workDirectory: workDirectory,
        onProgress: onProgress,
        useEveryAyahFallback: true,
      );
    }

    throw const QuranVideoExportException(
      'لا يوجد لهذا القارئ صوت آيات أو توقيت مزامنة كافٍ لإنشاء الفيديو. اختر قارئًا آخر من قائمة القراء.',
    );
  }

  Future<_PreparedAudioTrack> _preparePerAyahTrack({
    required ReciterAudioModel reciter,
    required int surahNumber,
    required List<int> verseNumbers,
    required Map<int, VerseTiming?> verseTimings,
    required Directory workDirectory,
    required QuranVideoProgressCallback onProgress,
    bool useEveryAyahFallback = false,
  }) async {
    final audioDirectory = Directory(p.join(workDirectory.path, 'audio'));
    await audioDirectory.create(recursive: true);
    final temporaryDirectory = await getTemporaryDirectory();
    final downloadDirectory = Directory(
      p.join(
        temporaryDirectory.path,
        'quran_video_audio',
        reciter.id,
        surahNumber.toString().padLeft(3, '0'),
      ),
    );
    await downloadDirectory.create(recursive: true);
    final clips = <_PreparedVerseAudio>[];
    final clipPaths = <String>[];
    var durationOffsetMs = 0;

    for (var index = 0; index < verseNumbers.length; index++) {
      _checkCancelled();
      final verseNumber = verseNumbers[index];
      final timing = verseTimings[verseNumber];
      final source = useEveryAyahFallback
          ? ReciterAudioHelper.getAyahAudioUrl(
              surahNumber,
              verseNumber,
              reciter,
            )
          : timing?.audioUrl;
      if (source == null || source.trim().isEmpty) {
        throw const QuranVideoExportException(
          'تعذر العثور على تسجيل إحدى الآيات المطلوبة.',
        );
      }

      final fileName =
          'ayah_${surahNumber.toString().padLeft(3, '0')}_${verseNumber.toString().padLeft(3, '0')}.mp3';
      final workingDestination = File(p.join(audioDirectory.path, fileName));
      final safeSource = await _resolveAudioInput(source, reciter);
      final sourceUri = Uri.tryParse(source);
      final isLocal =
          sourceUri?.scheme == 'file' || File(safeSource).existsSync();
      final existingDuration = timing?.durationMs ?? 0;
      late final File destination;
      if (isLocal) {
        destination = workingDestination;
        await File(safeSource).copy(destination.path);
      } else {
        final downloadId =
            'quran-video:${reciter.id}:$surahNumber:$verseNumber';
        _activeResourceDownloadId = downloadId;
        try {
          final downloadedPath = await BackgroundResourceDownloadService
              .instance
              .downloadToPath(
                id: downloadId,
                url: safeSource,
                destinationPath: p.join(downloadDirectory.path, fileName),
                displayName: 'تلاوة الآية $verseNumber',
                onProgress: (currentFraction) {
                  final overall =
                      (index + currentFraction) / verseNumbers.length;
                  onProgress(
                    QuranVideoExportProgress(
                      fraction: 0.05 + overall * 0.29,
                      message:
                          'جارٍ تنزيل التلاوة (${index + 1}/${verseNumbers.length})…',
                    ),
                  );
                },
              );
          destination = File(downloadedPath);
          _stagedAudioPaths.add(downloadedPath);
        } finally {
          if (_activeResourceDownloadId == downloadId) {
            _activeResourceDownloadId = null;
          }
        }
      }
      _checkCancelled();

      final lastSegmentEnd = timing?.segments.isNotEmpty == true
          ? timing!.segments.last.endMs
          : 0;
      var durationMs = existingDuration;
      if (durationMs <= 0 || durationMs < lastSegmentEnd) {
        durationMs = await _probeDurationMs(destination.path);
      }
      if (durationMs <= 0) durationMs = lastSegmentEnd;
      if (durationMs <= 0) {
        throw const QuranVideoExportException(
          'تعذر تحديد مدة أحد المقاطع الصوتية، لذلك لن أصدّر فيديو غير متزامن.',
        );
      }
      durationMs = durationMs < lastSegmentEnd ? lastSegmentEnd : durationMs;

      clips.add(
        _PreparedVerseAudio(
          verseNumber: verseNumber,
          durationMs: durationMs,
          timing: timing,
        ),
      );
      clipPaths.add(destination.path);
      durationOffsetMs += durationMs;
    }

    final manifest = File(p.join(workDirectory.path, 'audio.ffconcat'));
    final manifestText = StringBuffer('ffconcat version 1.0\n');
    for (final clipPath in clipPaths) {
      manifestText.writeln('file ${_escapeConcatPath(clipPath)}');
    }
    await manifest.writeAsString(
      manifestText.toString(),
      encoding: utf8,
      flush: true,
    );

    return _PreparedAudioTrack(
      kind: QuranVideoAudioKind.concatenatedVerses,
      input: manifest.path,
      durationMs: durationOffsetMs,
      verses: clips,
    );
  }

  List<QuranVideoSubtitleCue> _buildSubtitleCues({
    required _PreparedAudioTrack track,
    required int surahNumber,
    required QuranVideoDisplayMode displayMode,
  }) {
    final cues = <QuranVideoSubtitleCue>[];
    var cumulativeOffsetMs = 0;
    for (final verseAudio in track.verses) {
      final verseNumber = verseAudio.verseNumber;
      final timing = verseAudio.timing;
      final text = quran.getVerse(surahNumber, verseNumber);
      final words = text
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty) {
        if (track.kind == QuranVideoAudioKind.concatenatedVerses) {
          cumulativeOffsetMs += verseAudio.durationMs;
        }
        continue;
      }

      if (displayMode == QuranVideoDisplayMode.ayahByAyah ||
          timing?.segments.isNotEmpty != true) {
        final startMs = track.kind == QuranVideoAudioKind.fullSurah
            ? timing!.timestampFrom - track.clipStartMs
            : cumulativeOffsetMs;
        final endMs = track.kind == QuranVideoAudioKind.fullSurah
            ? timing!.timestampTo - track.clipStartMs
            : cumulativeOffsetMs + verseAudio.durationMs;
        if (endMs > startMs) {
          cues.add(
            QuranVideoSubtitleCue(startMs: startMs, endMs: endMs, words: words),
          );
        }
      } else {
        final segments = timing!.segments;
        final segmentClockIsSurah =
            track.kind == QuranVideoAudioKind.fullSurah &&
            timing.timestampFrom > 0 &&
            segments.first.startMs >= timing.timestampFrom &&
            segments.last.endMs <= timing.timestampTo;
        final wordIndexOffset = segments.first.wordIndex == 0 ? 1 : 0;
        final wordIntervals = <int, List<int>>{};
        for (final segment in segments) {
          final wordIndex = segment.wordIndex + wordIndexOffset;
          if (wordIndex < 1 || wordIndex > words.length) continue;
          final localStart = track.kind == QuranVideoAudioKind.fullSurah
              ? (segmentClockIsSurah
                        ? segment.startMs
                        : timing.timestampFrom + segment.startMs) -
                    track.clipStartMs
              : segment.startMs;
          final localEnd = track.kind == QuranVideoAudioKind.fullSurah
              ? (segmentClockIsSurah
                        ? segment.endMs
                        : timing.timestampFrom + segment.endMs) -
                    track.clipStartMs
              : segment.endMs;
          final startMs = track.kind == QuranVideoAudioKind.fullSurah
              ? localStart
              : cumulativeOffsetMs + localStart;
          final endMs = track.kind == QuranVideoAudioKind.fullSurah
              ? localEnd
              : cumulativeOffsetMs + localEnd;
          if (endMs <= startMs) continue;
          final interval = wordIntervals.putIfAbsent(
            wordIndex,
            () => [startMs, endMs],
          );
          if (startMs < interval[0]) interval[0] = startMs;
          if (endMs > interval[1]) interval[1] = endMs;
        }
        final orderedWordIntervals = wordIntervals.entries.toList()
          ..sort((first, second) => first.value[0].compareTo(second.value[0]));
        for (final entry in orderedWordIntervals) {
          cues.add(
            QuranVideoSubtitleCue(
              startMs: entry.value[0],
              endMs: entry.value[1],
              words: words,
              highlightedWordIndex: entry.key,
            ),
          );
        }
      }

      if (track.kind == QuranVideoAudioKind.concatenatedVerses) {
        cumulativeOffsetMs += verseAudio.durationMs;
      }
    }
    return cues;
  }

  Future<String> _resolveAudioInput(
    String source,
    ReciterAudioModel reciter,
  ) async {
    final uri = Uri.tryParse(source.trim());
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      if (reciter.localOnly || uri.userInfo.isNotEmpty) {
        throw const QuranVideoExportException('رابط الصوت غير صالح.');
      }
      return uri.toString();
    }
    if (uri != null && uri.scheme == 'file') {
      if (!reciter.localOnly ||
          !await FeatureResourceRepository.configured.containsFileUri(uri)) {
        throw const QuranVideoExportException(
          'ملف الصوت المحلي ليس ضمن مصادر التطبيق الموثوقة.',
        );
      }
      final localPath = uri.toFilePath();
      if (!await File(localPath).exists()) {
        throw const QuranVideoExportException('ملف الصوت المحلي غير متاح.');
      }
      return localPath;
    }
    if (reciter.localOnly) {
      final localFile = File(source);
      if (await localFile.exists() &&
          await FeatureResourceRepository.configured.containsFileUri(
            localFile.absolute.uri,
          )) {
        return localFile.path;
      }
    }
    throw const QuranVideoExportException(
      'رابط تسجيل القارئ غير مدعوم أو غير آمن.',
    );
  }

  Future<int> _probeDurationMs(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      final duration = double.tryParse(info?.getDuration() ?? '');
      if (duration == null || !duration.isFinite || duration <= 0) return 0;
      return (duration * 1000).round();
    } catch (_) {
      return 0;
    }
  }

  String _videoEncoderForCurrentPlatform() {
    if (Platform.isIOS) return 'h264_videotoolbox';
    if (Platform.isAndroid) return 'h264_mediacodec';
    throw const QuranVideoExportException(
      'إنشاء الفيديو متاح حاليًا على أجهزة Android وiOS فقط.',
    );
  }

  bool _validVerseBounds(VerseTiming timing) =>
      timing.timestampFrom >= 0 && timing.timestampTo > timing.timestampFrom;

  String _escapeConcatPath(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll(' ', r'\ ')
      .replaceAll("'", r"\'")
      .replaceAll('\n', '')
      .replaceAll('\r', '');

  void _checkCancelled() {
    if (_cancelRequested) {
      throw const QuranVideoExportException('تم إلغاء إنشاء الفيديو.');
    }
  }
}
