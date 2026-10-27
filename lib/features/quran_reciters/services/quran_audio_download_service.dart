import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibad_al_rahmann/core/data/quran_audio_index.dart';
import 'package:ibad_al_rahmann/core/helpers/background_resource_download_service.dart';

enum AudioDownloadState { notDownloaded, downloading, downloaded }

class QuranAudioDownloadService extends ChangeNotifier {
  static final QuranAudioDownloadService _instance =
      QuranAudioDownloadService._internal();
  factory QuranAudioDownloadService() => _instance;
  QuranAudioDownloadService._internal();

  // Track download states.
  final Map<String, AudioDownloadState> _states = {};
  // Track download progress (0.0 to 1.0).
  final Map<String, double> _progress = {};

  String _getKey(String reciterId, int surahNumber) =>
      '${reciterId}_$surahNumber';

  String _downloadId(String reciterId, int surahNumber) =>
      'quran-audio:$reciterId:$surahNumber';

  AudioDownloadState getState(String reciterId, int surahNumber) =>
      _states[_getKey(reciterId, surahNumber)] ??
      AudioDownloadState.notDownloaded;

  double getProgress(String reciterId, int surahNumber) =>
      _progress[_getKey(reciterId, surahNumber)] ?? 0.0;

  Future<String> getOfflineSurahPath(String reciterId, int surahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/quran_offline/$reciterId');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return '${offlineDir.path}/${surahNumber.toString().padLeft(3, '0')}.mp3';
  }

  Future<void> checkState(String reciterId, int surahNumber) async {
    final key = _getKey(reciterId, surahNumber);
    if (_states[key] == AudioDownloadState.downloading) return;

    final path = await getOfflineSurahPath(reciterId, surahNumber);
    final finalFile = File(path);
    if (!await finalFile.exists()) {
      final completedPath = await BackgroundResourceDownloadService.instance
          .completedPathFor(_downloadId(reciterId, surahNumber));
      if (completedPath != null && completedPath != path) {
        try {
          await File(completedPath).rename(path);
        } catch (_) {
          // The native task may be cleaned up while the app is reopening.
        }
      }
    }
    _states[key] = await finalFile.exists()
        ? AudioDownloadState.downloaded
        : AudioDownloadState.notDownloaded;
    notifyListeners();
  }

  Future<void> downloadSurah(String reciterId, int surahNumber) async {
    final key = _getKey(reciterId, surahNumber);
    if (_states[key] == AudioDownloadState.downloading ||
        _states[key] == AudioDownloadState.downloaded) {
      return;
    }

    String? audioUrl;
    if (QuranAudioIndex.surahData.containsKey(reciterId)) {
      final data = QuranAudioIndex.surahData[reciterId]!;
      if (data.containsKey(surahNumber.toString())) {
        audioUrl = data[surahNumber.toString()]!['audio_url'];
      }
    }
    audioUrl ??=
        'https://audio-cdn.tarteel.ai/quran/surah/$reciterId/murattal/mp3/${surahNumber.toString().padLeft(3, '0')}.mp3';

    _states[key] = AudioDownloadState.downloading;
    _progress[key] = 0.0;
    notifyListeners();

    final path = await getOfflineSurahPath(reciterId, surahNumber);
    final tempPath = '$path.tmp';
    try {
      final downloadedPath = await BackgroundResourceDownloadService.instance
          .downloadToPath(
            id: _downloadId(reciterId, surahNumber),
            url: audioUrl,
            destinationPath: tempPath,
            displayName: 'تلاوة السورة $surahNumber',
            onProgress: (progress) {
              _progress[key] = progress;
              notifyListeners();
            },
          );
      final tempFile = File(downloadedPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw StateError('empty_audio_download');
      }
      await tempFile.rename(path);

      _states[key] = AudioDownloadState.downloaded;
      _progress.remove(key);
      notifyListeners();
    } catch (error) {
      debugPrint('Download error for $key: ${error.runtimeType}');
      _states[key] = AudioDownloadState.notDownloaded;
      _progress.remove(key);
      try {
        if (await File(tempPath).exists()) await File(tempPath).delete();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> deleteSurah(String reciterId, int surahNumber) async {
    final key = _getKey(reciterId, surahNumber);
    await BackgroundResourceDownloadService.instance.cancel(
      _downloadId(reciterId, surahNumber),
    );
    final path = await getOfflineSurahPath(reciterId, surahNumber);
    for (final candidate in [path, '$path.tmp']) {
      final file = File(candidate);
      if (await file.exists()) await file.delete();
    }
    _states[key] = AudioDownloadState.notDownloaded;
    _progress.remove(key);
    notifyListeners();
  }
}
