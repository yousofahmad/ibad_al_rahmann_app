import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibad_al_rahmann/core/data/quran_audio_index.dart';

enum AudioDownloadState { notDownloaded, downloading, downloaded }

class QuranAudioDownloadService extends ChangeNotifier {
  static final QuranAudioDownloadService _instance = QuranAudioDownloadService._internal();
  factory QuranAudioDownloadService() => _instance;
  QuranAudioDownloadService._internal();

  final Dio _dio = Dio();
  
  // Track download states
  final Map<String, AudioDownloadState> _states = {};
  // Track download progress (0.0 to 1.0)
  final Map<String, double> _progress = {};

  String _getKey(String reciterId, int surahNumber) => "${reciterId}_$surahNumber";

  AudioDownloadState getState(String reciterId, int surahNumber) {
    return _states[_getKey(reciterId, surahNumber)] ?? AudioDownloadState.notDownloaded;
  }

  double getProgress(String reciterId, int surahNumber) {
    return _progress[_getKey(reciterId, surahNumber)] ?? 0.0;
  }

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
    if (await File(path).exists()) {
      _states[key] = AudioDownloadState.downloaded;
    } else {
      _states[key] = AudioDownloadState.notDownloaded;
    }
    notifyListeners();
  }

  Future<void> downloadSurah(String reciterId, int surahNumber) async {
    final key = _getKey(reciterId, surahNumber);
    if (_states[key] == AudioDownloadState.downloading || _states[key] == AudioDownloadState.downloaded) return;

    // Resolve URL from index
    String? audioUrl;
    if (QuranAudioIndex.surahData.containsKey(reciterId)) {
      final data = QuranAudioIndex.surahData[reciterId]!;
      if (data.containsKey(surahNumber.toString())) {
        audioUrl = data[surahNumber.toString()]!['audio_url'];
      }
    }
    
    if (audioUrl == null) {
      audioUrl = "https://audio-cdn.tarteel.ai/quran/surah/$reciterId/murattal/mp3/${surahNumber.toString().padLeft(3, '0')}.mp3";
    }

    _states[key] = AudioDownloadState.downloading;
    _progress[key] = 0.0;
    notifyListeners();

    final path = await getOfflineSurahPath(reciterId, surahNumber);
    final tempPath = "$path.tmp";

    try {
      await _dio.download(
        audioUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _progress[key] = received / total;
            notifyListeners();
          }
        },
      );

      final tempFile = File(tempPath);
      await tempFile.rename(path);

      _states[key] = AudioDownloadState.downloaded;
      _progress.remove(key);
      notifyListeners();
    } catch (e) {
      debugPrint("Download error for $key: $e");
      _states[key] = AudioDownloadState.notDownloaded;
      _progress.remove(key);
      try {
        if (await File(tempPath).exists()) {
          await File(tempPath).delete();
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> deleteSurah(String reciterId, int surahNumber) async {
    final key = _getKey(reciterId, surahNumber);
    final path = await getOfflineSurahPath(reciterId, surahNumber);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _states[key] = AudioDownloadState.notDownloaded;
    notifyListeners();
  }
}
