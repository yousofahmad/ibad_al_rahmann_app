import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class QuranVideoBackgroundPreviewService {
  const QuranVideoBackgroundPreviewService();

  Future<String> createVideoThumbnail(String videoPath) async {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
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
      return thumbnail.path;
    }

    for (final seekSeconds in <String?>[null, '0.25']) {
      if (await thumbnail.exists()) await thumbnail.delete();
      final session = await FFmpegKit.executeWithArguments(
        buildThumbnailArguments(
          videoPath: videoPath,
          thumbnailPath: thumbnail.path,
          seekSeconds: seekSeconds,
        ),
      );
      if (ReturnCode.isSuccess(await session.getReturnCode()) &&
          await thumbnail.exists() &&
          await thumbnail.length() > 0) {
        return thumbnail.path;
      }
    }

    throw const QuranVideoPreviewException();
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
