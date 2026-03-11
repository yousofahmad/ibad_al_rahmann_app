import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart'; // or just_audio
import 'package:ibad_al_rahmann/features/adhan/models/muezzin_model.dart';

class AdhanManager {
  static final AdhanManager _instance = AdhanManager._internal();
  factory AdhanManager() => _instance;
  AdhanManager._internal();

  final Dio _dio = Dio();
  final AudioPlayer _player = AudioPlayer();

  // --- 1. The Massive Library ---
  final List<Muezzin> _repository = [
    // --- Egypt ---
    Muezzin(
      id: 'egypt_abdulbasit',
      name: 'عبد الباسط عبد الصمد',
      country: 'مصر',
      category: 'Egypt',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Abdul_Basit_Abdul_Samad.mp3',
    ),
    /*
    Muezzin(
      id: 'egypt_minshawi',
      name: 'محمد صديق المنشاوي',
      country: 'مصر',
      category: 'Egypt',
      url:
          'https://media.blubrry.com/muslim_central_quran/podcasts.qurancentral.com/adhan/mohammad-siddiq-minshawi/adhan-mohammad-siddiq-minshawi-01.mp3',
    ),
    Muezzin(
      id: 'egypt_hosari',
      name: 'محمود خليل الحصري',
      country: 'مصر',
      category: 'Egypt',
      url:
          'https://media.blubrry.com/muslim_central_quran/podcasts.qurancentral.com/adhan/mahmoud-khalil-al-husary/adhan-mahmoud-khalil-al-husary-01.mp3',
    ),
    */
    Muezzin(
      id: 'egypt_ismail',
      name: 'مصطفى إسماعيل',
      country: 'مصر',
      category: 'Egypt',
      url: 'https://www.tvquran.com/uploads/adhan/Mustafa_Ismail.mp3',
    ),
    Muezzin(
      id: 'egypt_rifaat',
      name: 'محمد رفعت',
      country: 'مصر',
      category: 'Egypt',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Mohammad_Refaat.mp3',
    ),
    Muezzin(
      id: 'egypt_banna',
      name: 'محمود علي البنا',
      country: 'مصر',
      category: 'Egypt',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Mahmoud_Ali_Albanna.mp3',
    ),

    // --- Makkah ---
    /*
    Muezzin(
      id: 'makkah_mulla',
      name: 'علي أحمد ملا',
      country: 'السعودية',
      category: 'Makkah',
      url:
          'https://media.blubrry.com/muslim_central_quran/podcasts.qurancentral.com/adhan/ali-ahmed-mulla/adhan-ali-ahmed-mulla-01.mp3',
    ),
    */
    Muezzin(
      id: 'makkah_hadrawi',
      name: 'فاروق حضراوي',
      country: 'السعودية',
      category: 'Makkah',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Farouq_Abdmof_Hadraoui.mp3',
    ),
    Muezzin(
      id: 'makkah_faydah',
      name: 'نايف فيدة',
      country: 'السعودية',
      category: 'Makkah',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Naif_Saleh_Fiedah.mp3',
    ),

    // --- Madina ---
    Muezzin(
      id: 'madina_bukhari',
      name: 'عصام بخاري',
      country: 'السعودية',
      category: 'Madina',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Essam_Bukhari.mp3',
    ),
    Muezzin(
      id: 'madina_surayhi',
      name: 'عبدالمجيد السريحي',
      country: 'السعودية',
      category: 'Madina',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Abdulmajeed_Suraibi.mp3',
    ),
    Muezzin(
      id: 'madina_bakri',
      name: 'حسين رجب',
      country: 'السعودية',
      category: 'Madina',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Hussain_Rajab.mp3',
    ),

    // --- Al-Aqsa ---
    Muezzin(
      id: 'aqsa_official',
      name: 'أذان المسجد الأقصى',
      country: 'فلسطين',
      category: 'Al-Aqsa',
      url:
          'https://download.tvquran.com/download/Adhan/Low_Quality/Al-Aqsa.mp3',
    ),

    // --- Turkey ---
    Muezzin(
      id: 'turkey_istanbul',
      name: 'أذان إسطنبول',
      country: 'تركيا',
      category: 'Turkey',
      url: 'https://download.tvquran.com/download/Adhan/Low_Quality/Turkey.mp3',
    ),

    /*
    // --- Reciters ---
    Muezzin(
      id: 'reciter_mishary',
      name: 'مشاري راشد العفاسي',
      country: 'الكويت',
      category: 'Reciters',
      url:
          'https://media.blubrry.com/muslim_central_quran/podcasts.qurancentral.com/adhan/mishary-rashid-alafasy/adhan-mishary-rashid-alafasy-01.mp3',
    ),
    Muezzin(
      id: 'reciter_qatami',
      name: 'ناصر القطامي',
      country: 'السعودية',
      category: 'Reciters',
      url:
          'https://media.blubrry.com/muslim_central_quran/podcasts.qurancentral.com/adhan/nasser-al-qatami/adhan-nasser-al-qatami-01.mp3',
    ),
    */
  ];

  List<Muezzin> getMuezzins() => _repository;

  List<String> getCategories() {
    return _repository.map((e) => e.category).toSet().toList();
  }

  List<Muezzin> getByCategory(String category) {
    return _repository.where((e) => e.category == category).toList();
  }

  // --- 2. Download Logic ---

  Future<String> _getFilePath(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${dir.path}/adhans');
    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }
    return '${adhanDir.path}/$id.mp3';
  }

  Future<bool> isDownloaded(String id) async {
    final path = await _getFilePath(id);
    return File(path).exists();
  }

  Future<String?> getLocalPath(String id) async {
    final path = await _getFilePath(id);
    if (await File(path).exists()) return path;
    return null;
  }

  Future<void> downloadAdhan(
    Muezzin muezzin,
    Function(double progress) onProgress,
  ) async {
    final savePath = await _getFilePath(muezzin.id);
    try {
      await _dio.download(
        muezzin.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );
      debugPrint("Downloaded ${muezzin.name} to $savePath");
    } catch (e) {
      debugPrint("Download error: $e");
      rethrow;
    }
  }

  Future<void> deleteAdhan(String id) async {
    final path = await _getFilePath(id);
    final file = File(path);
    if (await file.exists()) {
      debugPrint('AdhanManager: Deleting $path'); // Added debugPrint
      await file.delete();
    }
  }

  // --- 3. Preview Logic ---

  Future<void> playPreview(Muezzin muezzin) async {
    // If downloaded, play local. Else play remote.
    final localPath = await getLocalPath(muezzin.id);
    if (localPath != null) {
      await _player.play(DeviceFileSource(localPath));
    } else {
      await _player.play(UrlSource(muezzin.url));
    }
  }

  Future<void> stopPreview() async {
    await _player.stop();
  }
}
