import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/muezzin_model.dart';

class MuezzinRepository {
  final Dio _dio = Dio();

  final List<Muezzin> _muezzins = [
    Muezzin(
      id: 'makkah_ali_mulla',
      name: 'الحرم المكي - علي ملا',
      url: 'https://download.media.islamweb.net/audio/download/mp3/1.mp3',
      fileName: 'azan_makkah_ali_mulla.mp3',
    ),
    Muezzin(
      id: 'makkah_hadrawi',
      name: 'الحرم المكي - فاروق حضراوي',
      url: 'https://download.media.islamweb.net/audio/download/mp3/85173.mp3',
      fileName: 'azan_makkah_hadrawi.mp3',
    ),
    Muezzin(
      id: 'makkah_fida',
      name: 'الحرم المكي - نايف فيده',
      url: 'https://download.media.islamweb.net/audio/download/mp3/85149.mp3',
      fileName: 'azan_makkah_fida.mp3',
    ),
    Muezzin(
      id: 'madina_essam',
      name: 'الحرم المدني - عصام بخاري',
      url: 'https://download.media.islamweb.net/audio/download/mp3/5.mp3',
      fileName: 'azan_madina_essam.mp3',
    ),
    Muezzin(
      id: 'aqsa_naji',
      name: 'المسجد الأقصى - ناجي قزاز',
      url: 'https://download.media.islamweb.net/audio/download/mp3/7.mp3',
      fileName: 'azan_aqsa_naji.mp3',
    ),
    Muezzin(
      id: 'egypt_abdulbasit',
      name: 'مصر - عبد الباسط عبد الصمد',
      url: 'https://download.media.islamweb.net/audio/download/mp3/122664.mp3',
      fileName: 'azan_egypt_abdulbasit.mp3',
    ),
    Muezzin(
      id: 'egypt_mustafa',
      name: 'مصر - مصطفى إسماعيل',
      url: 'https://download.media.islamweb.net/audio/download/mp3/176760.mp3',
      fileName: 'azan_egypt_mustafa.mp3',
    ),
    Muezzin(
      id: 'egypt_husari',
      name: 'مصر - محمود خليل الحصري',
      url: 'https://download.media.islamweb.net/audio/download/mp3/122667.mp3',
      fileName: 'azan_egypt_husari.mp3',
    ),
    Muezzin(
      id: 'egypt_minshawi',
      name: 'مصر - محمد صديق المنشاوي',
      url: 'https://download.media.islamweb.net/audio/download/mp3/88639.mp3',
      fileName: 'azan_egypt_minshawi.mp3',
    ),
    Muezzin(
      id: 'egypt_rifaat',
      name: 'مصر - محمد رفعت',
      url: 'https://download.media.islamweb.net/audio/download/mp3/122665.mp3',
      fileName: 'azan_egypt_rifaat.mp3',
    ),
    Muezzin(
      id: 'kuwait_mishary',
      name: 'الكويت - مشاري العفاسي',
      url: 'https://download.media.islamweb.net/audio/download/mp3/206930.mp3',
      fileName: 'azan_kuwait_mishary.mp3',
    ),
    Muezzin(
      id: 'qatar_emadi',
      name: 'قطر - أحمد العمادي',
      url: 'https://download.media.islamweb.net/audio/download/mp3/11.mp3',
      fileName: 'azan_qatar_emadi.mp3',
    ),
    Muezzin(
      id: 'turkey',
      name: 'تركيا',
      url: 'https://download.media.islamweb.net/audio/download/mp3/122644.mp3',
      fileName: 'azan_turkey.mp3',
    ),
    Muezzin(
      id: 'algeria',
      name: 'الجزائر - رياض الجزائري',
      url: 'https://download.media.islamweb.net/audio/download/mp3/317698.mp3',
      fileName: 'azan_algeria.mp3',
    ),
    Muezzin(
      id: 'palestine',
      name: 'فلسطين - صهيب هاني',
      url: 'https://download.media.islamweb.net/audio/download/mp3/200190.mp3',
      fileName: 'azan_palestine.mp3',
    ),
    Muezzin(
      id: 'malaysia',
      name: 'ماليزيا',
      url: 'https://download.media.islamweb.net/audio/download/mp3/122660.mp3',
      fileName: 'azan_malaysia.mp3',
    ),
    Muezzin(
      id: 'bosnia',
      name: 'البوسنة',
      url: 'https://download.media.islamweb.net/audio/download/mp3/203248.mp3',
      fileName: 'azan_bosnia.mp3',
    ),
  ];

  Future<List<Muezzin>> getMuezzins() async {
    final dir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${dir.path}/adhan');

    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }

    for (var muezzin in _muezzins) {
      final file = File('${adhanDir.path}/${muezzin.fileName}');
      if (await file.exists()) {
        muezzin.isDownloaded = true;
        muezzin.localPath = file.path;
      } else {
        muezzin.isDownloaded = false;
        muezzin.localPath = null;
      }
    }
    return _muezzins;
  }

  Future<String?> downloadMuezzin(
    Muezzin muezzin,
    Function(double) onProgress,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final adhanDir = Directory('${dir.path}/adhan');
      if (!await adhanDir.exists()) {
        await adhanDir.create(recursive: true);
      }

      final savePath = '${adhanDir.path}/${muezzin.fileName}';

      await _dio.download(
        muezzin.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      return savePath;
    } catch (e) {
      // print('Download error: $e');
      return null;
    }
  }
}
