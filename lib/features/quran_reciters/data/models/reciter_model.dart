import 'package:ibad_al_rahmann/core/data/quran_audio_index.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:archive/archive.dart';

enum ReciterHighlightSupport {
  wordByWord, // تظليل آيات وتظليل كلمة بكلمة
  verseOnly, // تظليل آيات فقط
  none, // سورة كاملة بدون تظليل
}

class WordSegment {
  final int wordIndex;
  final int startMs;
  final int endMs;

  WordSegment({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  factory WordSegment.fromList(List<dynamic> list) {
    if (list.isEmpty) return WordSegment(wordIndex: 0, startMs: 0, endMs: 0);

    final wIndex = int.tryParse(list[0].toString()) ?? 0;
    int sMs = 0;
    int eMs = 0;

    if (list.length >= 4) {
      // Format: [wordIndex, letter, startMs, endMs]
      sMs = int.tryParse(list[2].toString()) ?? 0;
      eMs = int.tryParse(list[3].toString()) ?? 0;
    } else if (list.length >= 3) {
      // Format: [wordIndex, startMs, endMs]
      sMs = int.tryParse(list[1].toString()) ?? 0;
      eMs = int.tryParse(list[2].toString()) ?? 0;
    } else if (list.length == 2) {
      sMs = int.tryParse(list[0].toString()) ?? 0;
      eMs = int.tryParse(list[1].toString()) ?? 0;
    }

    return WordSegment(wordIndex: wIndex, startMs: sMs, endMs: eMs);
  }
}

class VerseTiming {
  final int surahNumber;
  final int verseNumber;
  final String? audioUrl;
  final int timestampFrom;
  final int timestampTo;
  final int durationMs;
  final List<WordSegment> segments;

  VerseTiming({
    required this.surahNumber,
    required this.verseNumber,
    this.audioUrl,
    required this.timestampFrom,
    required this.timestampTo,
    required this.durationMs,
    required this.segments,
  });

  factory VerseTiming.fromJson(String key, Map<String, dynamic> json) {
    final parts = key.split(':');
    final sNum = parts.isNotEmpty
        ? (int.tryParse(parts[0]) ??
              (json['surah_number'] as num?)?.toInt() ??
              1)
        : ((json['surah_number'] as num?)?.toInt() ?? 1);
    final vNum = parts.length > 1
        ? (int.tryParse(parts[1]) ??
              (json['ayah_number'] as num?)?.toInt() ??
              1)
        : ((json['ayah_number'] as num?)?.toInt() ?? 1);

    final rawSegs = json['segments'] as List<dynamic>? ?? [];
    final segsList = rawSegs
        .whereType<List<dynamic>>()
        .map((e) => WordSegment.fromList(e))
        .toList();

    int startFrom = (json['timestamp_from'] as num?)?.toInt() ?? 0;
    int endTo = (json['timestamp_to'] as num?)?.toInt() ?? 0;

    if (startFrom == 0 && segsList.isNotEmpty) {
      startFrom = segsList.first.startMs;
    }
    if (endTo == 0 && segsList.isNotEmpty) {
      endTo = segsList.last.endMs;
    }

    int dur =
        (json['duration_ms'] as num?)?.toInt() ??
        ((json['duration'] as num?)?.toDouble() != null
            ? ((json['duration'] as num).toDouble() * 1000).toInt()
            : 0);

    if (dur == 0 && endTo > startFrom) {
      dur = endTo - startFrom;
    }

    return VerseTiming(
      surahNumber: sNum,
      verseNumber: vNum,
      audioUrl: json['audio_url']?.toString(),
      timestampFrom: startFrom,
      timestampTo: endTo,
      durationMs: dur,
      segments: segsList,
    );
  }
}

class SurahAudioItem {
  final int surahNumber;
  final String audioUrl;
  final int durationSec;

  SurahAudioItem({
    required this.surahNumber,
    required this.audioUrl,
    required this.durationSec,
  });

  factory SurahAudioItem.fromJson(Map<String, dynamic> json) {
    return SurahAudioItem(
      surahNumber: (json['surah_number'] as num?)?.toInt() ?? 1,
      audioUrl: json['audio_url']?.toString() ?? '',
      durationSec: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReciterAudioModel {
  final String id;
  final String name;
  final String style;
  final String folderName;
  final String everyAyahFolder;
  final bool hasSegments;
  final String? zipFileName;
  final String? segmentsFileName;
  final String category;

  ReciterAudioModel({
    required this.id,
    required this.name,
    required this.style,
    required this.folderName,
    this.everyAyahFolder = '',
    this.hasSegments = true,
    this.zipFileName,
    this.segmentsFileName,
    this.category = 'مشاهير القراء',
  });

  factory ReciterAudioModel.fromJson(Map<String, dynamic> json) {
    return ReciterAudioModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      style: json['style']?.toString() ?? 'مرتل',
      folderName: json['folder_name']?.toString() ?? '',
      everyAyahFolder: json['every_ayah_folder']?.toString() ?? '',
      hasSegments: json['has_segments'] ?? true,
      zipFileName: json['zip_file_name']?.toString(),
      segmentsFileName: json['segments_file_name']?.toString(),
      category: json['category']?.toString() ?? 'مشاهير القراء',
    );
  }

  ReciterHighlightSupport get highlightSupport {
    if (!hasSegments) return ReciterHighlightSupport.none;
    if (zipFileName != null ||
        folderName == 'surah-recitation-abdul-basit-abd-us-samad-mujawwad' ||
        segmentsFileName == 'letter_segments.json') {
      return ReciterHighlightSupport.wordByWord;
    }
    return ReciterHighlightSupport.verseOnly;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'style': style,
    'folder_name': folderName,
    'every_ayah_folder': everyAyahFolder,
    'has_segments': hasSegments,
    if (zipFileName != null) 'zip_file_name': zipFileName,
    if (segmentsFileName != null) 'segments_file_name': segmentsFileName,
    'category': category,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReciterAudioModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ReciterAudioHelper {
  static const String _baseUrl =
      "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/";

  static final List<ReciterAudioModel> defaultReciters = [
    // ─── Category A: ZIP + segments.json (Word-by-word support) ─────────────
    ReciterAudioModel(
      id: 'ahmad_alnufais',
      name: 'أحمد النفيس',
      style: 'مرتل',
      folderName: 'surah-recitation-ahmad-alnufais',
      everyAyahFolder: 'Ahmed_ibn_Ali_al-Ajamy_128kbps_kotSimple',
      hasSegments: true,
      zipFileName: 'ayah-recitation-alnufais.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'mishari_alafasy',
      name: 'مشاري راشد العفاسي',
      style: 'مرتل',
      folderName: 'surah-recitation-mishari-rashid-al-afasy',
      everyAyahFolder: 'Alafasy_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-mishari-rashid-al-afasy-murattal-hafs-953.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'abdulbasit_murattal',
      name: 'عبد الباسط عبد الصمد',
      style: 'مرتل',
      folderName: 'surah-recitation-abdul-basit-abd-us-samad-murattal',
      everyAyahFolder: 'Abdul_Basit_Murattal_192kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-abdul-basit-abdul-samad-murattal-hafs-950.json.zip',
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'mahmoud_husary_murattal',
      name: 'محمود خليل الحصري',
      style: 'مرتل',
      folderName: 'surah-recitation-mahmoud-husary-murattal',
      everyAyahFolder: 'Husary_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-mahmoud-khalil-al-husary-murattal-hafs-955.json.zip',
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'mahmoud_husary_mujawwad',
      name: 'محمود خليل الحصري',
      style: 'مجود',
      folderName: 'surah-recitation-mahmoud-husary-mujawwad',
      everyAyahFolder: 'Husary_Mujawwad_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-mahmoud-khalil-al-husary-mujawwad-hafs-956.json.zip',
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'husary_muallim',
      name: 'محمود خليل الحصري',
      style: 'المصحف المعلم',
      folderName: 'surah-recitation-mahmoud-khaleel-al-husary-muallam',
      everyAyahFolder: 'Husary_Muallim_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-mahmoud-khalil-al-husary-murattal-hafs-957.json.zip',
      segmentsFileName: 'segments.json',
      category: 'المصحف المعلم',
    ),
    ReciterAudioModel(
      id: 'sudais',
      name: 'عبد الرحمن السديس',
      style: 'مرتل',
      folderName: 'surah-recitation-abdul-rahman-al-sudais',
      everyAyahFolder: 'Abdurrahmaan_As-Sudais_192kbps',
      hasSegments: true,
      zipFileName: 'ayah-recitation-abdur-rahman-as-sudais-recitation.json.zip',
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'shuraim',
      name: 'سعود الشريم',
      style: 'مرتل',
      folderName: 'surah-recitation-saud-al-shuraim',
      everyAyahFolder: 'Saood_ash-Shuraym_128kbps',
      hasSegments: true,
      zipFileName: 'ayah-recitation-saud-al-shuraim-murattal-hafs-960.json.zip',
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'muaiqly',
      name: 'ماهر المعيقلي',
      style: 'مرتل',
      folderName: 'surah-recitation-maher-al-muaiqly',
      everyAyahFolder: 'Maher_AlMuaiqly_64kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-maher-al-mu-aiqly-murattal-hafs-948.json.zip',
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'dosari',
      name: 'ياسر الدوسري',
      style: 'مرتل',
      folderName: 'surah-recitation-yasser-al-dosari',
      everyAyahFolder: 'Yasser_Ad-Dussary_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-yasser-al-dosari-murattal-hafs-961.json.zip',
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'shatri',
      name: 'أبو بكر الشاطري',
      style: 'مرتل',
      folderName: 'surah-recitation-abu-bakr-al-shatri',
      everyAyahFolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-abu-bakr-al-shatri-murattal-hafs-952.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'ghamdi',
      name: 'سعد الغامدي',
      style: 'مرتل',
      folderName: 'surah-recitation-saad-ghamadi',
      everyAyahFolder: 'Ghamadi_40kbps',
      hasSegments: true,
      zipFileName: 'ayah-recitation-saad-al-ghamdi-murattal-hafs-954.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'rifai',
      name: 'هاني الرفاعي',
      style: 'مرتل',
      folderName: 'surah-recitation-hani-ar-rifai',
      everyAyahFolder: 'Hani_Rifai_192kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-hani-ar-rifai-recitation-murattal-hafs-68.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'tunaiji',
      name: 'خليفة الطنيجي',
      style: 'مرتل',
      folderName: 'surah-recitation-khalifa-al-tunaiji',
      everyAyahFolder: 'khalefa_al_tunaiji_64kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-khalifa-al-tunaiji-murattal-hafs-958.json.zip',
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'tablawi',
      name: 'محمد محمود الطبلاوي',
      style: 'مرتل',
      folderName: 'surah-recitation-mohammad-al-tablawi',
      everyAyahFolder: 'Mohammad_al_Tablaway_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-mohamed-al-tablawi-recitation-murattal-hafs-73.json.zip',
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'minshawi_murattal2',
      name: 'محمد صديق المنشاوي',
      style: 'مرتل (مصحف ٢)',
      folderName: 'surah-recitation-muhammad-siddiq-al-minshawy-murattal',
      everyAyahFolder: 'Minshawy_Murattal_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json.zip',
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    // ─── Category C: ZIP + letter_segments.json ────────────────────────────
    ReciterAudioModel(
      id: 'abdulbasit_mujawwad',
      name: 'عبد الباسط عبد الصمد',
      style: 'مجود',
      folderName: 'surah-recitation-abdul-basit-abd-us-samad-mujawwad',
      everyAyahFolder: 'Abdul_Basit_Mujawwad_128kbps',
      hasSegments: true,
      zipFileName:
          'ayah-recitation-abdul-basit-abdul-samad-mujawwad-hafs-949.json.zip',
      segmentsFileName: 'letter_segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    // ─── Category B: segments.json (direct / EveryAyah timing) ──────────────
    ReciterAudioModel(
      id: 'minshawi_murattal',
      name: 'محمد صديق المنشاوي',
      style: 'مرتل',
      folderName: 'surah-recitation-muhammad-siddiq-al-minshawi',
      everyAyahFolder: 'Minshawy_Murattal_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'minshawi_with_kids',
      name: 'محمد صديق المنشاوي',
      style: 'المصحف المعلم وترديد أطفال',
      folderName: 'surah-recitation-muhammad-siddiq-al-minshawi-with-kids',
      everyAyahFolder: 'Minshawy_Teacher_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'المصحف المعلم',
    ),
    ReciterAudioModel(
      id: 'jibreel',
      name: 'محمد جبريل',
      style: 'مرتل',
      folderName: 'surah-recitation-muhammad-jibreel',
      everyAyahFolder: 'Muhammad_Jibreel_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'banna',
      name: 'محمود علي البنا',
      style: 'مرتل',
      folderName: 'surah-recitation-mahmood-ali-al-bana',
      everyAyahFolder: 'Mahmoud_Ali_Al_Banna_32kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'mustafa_ismail',
      name: 'مصطفى إسماعيل',
      style: 'مرتل',
      folderName: 'surah-recitation-mostafa-ismaeel',
      everyAyahFolder: 'Mustafa_Ismail_48kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'nauina',
      name: 'أحمد نعينع',
      style: 'مرتل',
      folderName: 'surah-recitation-ahmad-nauina',
      everyAyahFolder: 'Ahmed_Neana_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'عمالقة القراء (مصر)',
    ),
    ReciterAudioModel(
      id: 'jalil',
      name: 'خالد الجليل',
      style: 'مرتل',
      folderName: 'surah-recitation-khalid-al-jalil',
      everyAyahFolder: 'Khalid_Al-Jileel_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'qatami',
      name: 'ناصر القطامي',
      style: 'مرتل',
      folderName: 'surah-recitation-nasser-al-qatami',
      everyAyahFolder: 'Nasser_Alqatami_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'fares_abbad',
      name: 'فارس عباد',
      style: 'مرتل',
      folderName: 'surah-recitation-fares-abbad',
      everyAyahFolder: 'Fares_Abbad_64kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'salimi',
      name: 'منصور السالمي',
      style: 'مرتل',
      folderName: 'surah-recitation-mansour-al-salimi-1444h',
      everyAyahFolder: 'Mansoor_Al-Salimi_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'basfar',
      name: 'عبد الله بصفر',
      style: 'مرتل',
      folderName: 'surah-recitation-abdullah-basfar',
      everyAyahFolder: 'Abdullah_Basfar_192kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'matroud',
      name: 'عبد الله مطرود',
      style: 'مرتل',
      folderName: 'surah-recitation-abdullah-matroud',
      everyAyahFolder: 'Abdullah_Matroud_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'sahl_yasin',
      name: 'سهل ياسين',
      style: 'مرتل',
      folderName: 'surah-recitation-sahl-yasin',
      everyAyahFolder: 'Sahl_Yasin_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'bukhatir',
      name: 'صلاح بوخاطر',
      style: 'مرتل',
      folderName: 'surah-recitation-salah-bukhatir',
      everyAyahFolder: 'Salah_Bukhatir_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'juhani',
      name: 'عبد الله عواد الجهني',
      style: 'مرتل',
      folderName: 'surah-recitation-abdullah-awad-al-juhani',
      everyAyahFolder: 'Abdullah_Al-Juhany_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'ali_jaber',
      name: 'عبد الله علي جابر',
      style: 'مرتل',
      folderName: 'surah-recitation-abdullah-ali-jabir',
      everyAyahFolder: 'Ali_Jaber_64kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'budair',
      name: 'صلاح البدير',
      style: 'مرتل',
      folderName: 'surah-recitation-salah-al-budair',
      everyAyahFolder: 'Salah_Al_Budair_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'baleela',
      name: 'بندر بليلة',
      style: 'مرتل',
      folderName: 'surah-recitation-bandar-baleela',
      everyAyahFolder: 'Bandar_Baleela_128kbps',
      hasSegments: true,
      segmentsFileName: 'segments.json',
      category: 'أئمة الحرمين الشريفين',
    ),
    // ─── Category D: Verse-by-verse & surah audio ──────────────────────────
    ReciterAudioModel(
      id: 'kalbani',
      name: 'عادل الكلباني',
      style: 'مرتل',
      folderName: 'surah-recitation-adel-kalbani',
      everyAyahFolder: 'Adel_Kalbani_128kbps',
      hasSegments: false,
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'huthaify',
      name: 'علي عبد الرحمن الحذيفي',
      style: 'مرتل',
      folderName: 'surah-recitation-ali-abdur-rahman-al-huthaify',
      everyAyahFolder: 'Hudhaify_128kbps',
      hasSegments: false,
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'akhdar',
      name: 'إبراهيم الأخضر',
      style: 'مرتل',
      folderName: 'surah-recitation-ibrahim-al-akhdar',
      everyAyahFolder: 'Ibrahim_Akhdar_32kbps',
      hasSegments: false,
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'ayyoob',
      name: 'محمد أيوب',
      style: 'مرتل',
      folderName: 'surah-recitation-muhammad-ayyoob',
      everyAyahFolder: 'Muhammad_Ayyoub_128kbps',
      hasSegments: false,
      category: 'أئمة الحرمين الشريفين',
    ),
    ReciterAudioModel(
      id: 'wadee_yamani',
      name: 'وديع اليمني',
      style: 'مرتل',
      folderName: 'surah-recitation-wadee-hammadi-al-yamani',
      everyAyahFolder: 'Wadi_Al-Yamani_128kbps',
      hasSegments: false,
      category: 'مشاهير القراء',
    ),
    ReciterAudioModel(
      id: 'noreen_siddiq',
      name: 'نورين محمد صديق',
      style: 'رواية الدوري عن أبي عمرو',
      folderName: 'surah-recitation-noreen-siddiq-ad-doori-an-abi-amr',
      everyAyahFolder: 'Noreen_Siddiq_128kbps',
      hasSegments: false,
      category: 'قراءات وروايات',
    ),
  ];

  static List<ReciterAudioModel> _availableReciters = List.from(
    defaultReciters,
  );
  static final Map<String, Map<int, SurahAudioItem>> _surahsCache = {};
  static final Map<String, Map<String, VerseTiming>> _segmentsCache = {};

  static List<ReciterAudioModel> get availableReciters => _availableReciters;
  static Future<List<ReciterAudioModel>> getReciters() async =>
      _availableReciters;

  static ReciterAudioModel getReciterById(String id) {
    return _availableReciters.firstWhere(
      (r) => r.id == id,
      orElse: () => defaultReciters.first,
    );
  }

  static String getAyahAudioUrl(
    int surahNumber,
    int verseNumber,
    ReciterAudioModel reciter,
  ) {
    final folder = reciter.everyAyahFolder.isNotEmpty
        ? reciter.everyAyahFolder
        : (reciter.folderName.isNotEmpty
            ? reciter.folderName
            : 'Alafasy_128kbps');
    final s = surahNumber.toString().padLeft(3, '0');
    final v = verseNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$v.mp3';
  }

  static Future<void> fetchRemoteReciters() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final response = await dio.get('${_baseUrl}app_config.json');
      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;
        if (data is Map && data.containsKey('audio_reciters')) {
          final list = (data['audio_reciters'] as List)
              .map(
                (e) => ReciterAudioModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
          if (list.isNotEmpty) {
            _availableReciters = list;
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch remote audio reciters: $e");
    }
  }

  static Future<String> _getReciterDir(String folderName) async {
    final dir = await getApplicationDocumentsDirectory();
    final reciterDir = Directory('${dir.path}/quran_offline/$folderName');
    if (!await reciterDir.exists()) {
      await reciterDir.create(recursive: true);
    }
    return reciterDir.path;
  }

  static Future<Map<int, SurahAudioItem>> getSurahs(
    ReciterAudioModel reciter,
  ) async {
    if (_surahsCache.containsKey(reciter.folderName) &&
        _surahsCache[reciter.folderName]!.isNotEmpty) {
      return _surahsCache[reciter.folderName]!;
    }

    if (QuranAudioIndex.surahData.containsKey(reciter.folderName)) {
      final data = QuranAudioIndex.surahData[reciter.folderName]!;
      final result = <int, SurahAudioItem>{};
      data.forEach((k, v) {
        final item = SurahAudioItem.fromJson(Map<String, dynamic>.from(v));
        result[item.surahNumber] = item;
      });
      _surahsCache[reciter.folderName] = result;
      return result;
    }

    final localDir = await _getReciterDir(reciter.folderName);
    final localFile = File('$localDir/surah.json');

    dynamic jsonData;
    if (await localFile.exists()) {
      final str = await localFile.readAsString();
      jsonData = json.decode(str);
    } else {
      try {
        final dio = Dio();
        final urls = [
          '${_baseUrl}reciters/${reciter.folderName}/surah.json',
          '${_baseUrl}audio/reciters/${reciter.folderName}/surah.json',
        ];
        for (final url in urls) {
          try {
            final response = await dio.get(url);
            if (response.statusCode == 200) {
              jsonData = response.data is String
                  ? json.decode(response.data)
                  : response.data;
              await localFile.writeAsString(json.encode(jsonData));
              break;
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("Error fetching surah.json for ${reciter.name}: $e");
      }
    }

    final result = <int, SurahAudioItem>{};
    if (jsonData != null) {
      if (jsonData is Map) {
        jsonData.forEach((k, v) {
          if (v is Map) {
            final item = SurahAudioItem.fromJson(Map<String, dynamic>.from(v));
            result[item.surahNumber] = item;
          }
        });
      } else if (jsonData is List) {
        for (var v in jsonData) {
          if (v is Map) {
            final item = SurahAudioItem.fromJson(Map<String, dynamic>.from(v));
            result[item.surahNumber] = item;
          }
        }
      }
    }

    _surahsCache[reciter.folderName] = result;
    return result;
  }

  static Future<Map<String, VerseTiming>> getSegments(
    ReciterAudioModel reciter,
  ) async {
    // Category D: no timing data available
    if (!reciter.hasSegments) return {};

    if (_segmentsCache.containsKey(reciter.folderName) &&
        _segmentsCache[reciter.folderName]!.isNotEmpty) {
      return _segmentsCache[reciter.folderName]!;
    }

    final localDir = await _getReciterDir(reciter.folderName);
    final segmentsFile = File('$localDir/segments.json');
    final letterFile = File('$localDir/letter_segments.json');

    dynamic jsonData;

    // Check locally cached files first
    if (await segmentsFile.exists()) {
      jsonData = json.decode(await segmentsFile.readAsString());
    } else if (await letterFile.exists()) {
      jsonData = json.decode(await letterFile.readAsString());
    } else {
      // 1. Check bundled app assets for instant offline word-by-word timing
      if (reciter.zipFileName != null) {
        try {
          final assetData = await rootBundle.load(
            'assets/data/reciters_timing/${reciter.zipFileName}',
          );
          final bytes = assetData.buffer.asUint8List();
          if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
            final archive = ZipDecoder().decodeBytes(bytes);
            for (final file in archive) {
              if (file.isFile && file.name.endsWith('.json')) {
                final content = utf8.decode(file.content as List<int>);
                jsonData = json.decode(content);
                await segmentsFile.writeAsString(content);
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('getSegments rootBundle load error: $e');
        }
      }

      // 2. Direct fetch from remote if not in bundled assets
      if (jsonData == null) {
        try {
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

          // a. Reciter has a ZIP file — fetch & extract
          if (reciter.zipFileName != null) {
            final zipUrl =
                '${_baseUrl}audio/reciters/${reciter.folderName}/${reciter.zipFileName}';
            final response = await dio.get<List<int>>(
              zipUrl,
              options: Options(responseType: ResponseType.bytes),
            );
            if (response.statusCode == 200 && response.data != null) {
              final bytes = response.data!;
              // Validate ZIP magic bytes (PK header: 0x50 0x4B)
              if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
                final archive = ZipDecoder().decodeBytes(bytes);
                for (final file in archive) {
                  if (file.isFile && file.name.endsWith('.json')) {
                    final content = utf8.decode(file.content as List<int>);
                    jsonData = json.decode(content);
                    // Cache locally as segments.json regardless of original name
                    await segmentsFile.writeAsString(content);
                    break;
                  }
                }
              }
            }
          }

          // b. No ZIP (or ZIP failed) — fetch plain JSON directly
          if (jsonData == null && reciter.segmentsFileName != null) {
            final segUrl =
                '${_baseUrl}audio/reciters/${reciter.folderName}/${reciter.segmentsFileName}';
            final response = await dio.get<dynamic>(segUrl);
            if (response.statusCode == 200 && response.data != null) {
              jsonData = response.data is String
                  ? json.decode(response.data as String)
                  : response.data;
              final targetFile =
                  reciter.segmentsFileName == 'letter_segments.json'
                  ? letterFile
                  : segmentsFile;
              await targetFile.writeAsString(json.encode(jsonData));
            }
          }
        } catch (e) {
          debugPrint("Error fetching segments for ${reciter.name}: $e");
        }
      }
    }

    final result = <String, VerseTiming>{};
    if (jsonData is Map) {
      jsonData.forEach((k, v) {
        if (v is Map) {
          final timing = VerseTiming.fromJson(
            k.toString(),
            Map<String, dynamic>.from(v),
          );
          result['${timing.surahNumber}:${timing.verseNumber}'] = timing;
        }
      });
    }

    _segmentsCache[reciter.folderName] = result;
    return result;
  }

  static Future<String> getOfflineSurahPath(
    String folderName,
    int surahNumber,
  ) async {
    final localDir = await _getReciterDir(folderName);
    return '$localDir/${surahNumber.toString().padLeft(3, '0')}.mp3';
  }

  static Future<bool> isSurahDownloaded(
    String folderName,
    int surahNumber,
  ) async {
    final path = await getOfflineSurahPath(folderName, surahNumber);
    return File(path).exists();
  }

  static Future<void> downloadSurah(
    String folderName,
    int surahNumber,
    String remoteUrl, {
    required void Function(double progress) onProgress,
    required void Function(bool success, String? error) onComplete,
  }) async {
    try {
      final filePath = await getOfflineSurahPath(folderName, surahNumber);
      final tempPath = '$filePath.tmp';

      final dio = Dio();
      await dio.download(
        remoteUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(filePath);
        onComplete(true, null);
      } else {
        onComplete(false, 'فشل حفظ الملف الصوتي');
      }
    } catch (e) {
      debugPrint("Error downloading surah $surahNumber for $folderName: $e");
      onComplete(false, e.toString());
    }
  }

  static Future<void> deleteDownloadedSurah(
    String folderName,
    int surahNumber,
  ) async {
    try {
      final path = await getOfflineSurahPath(folderName, surahNumber);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error deleting surah $surahNumber: $e");
    }
  }
}
