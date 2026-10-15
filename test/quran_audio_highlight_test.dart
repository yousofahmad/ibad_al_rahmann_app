import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quran Audio & Reciter Model Tests', () {
    test('ReciterAudioModel equality and hashCode work by id', () {
      final r1 = ReciterAudioModel(
        id: 'mishari_alafasy',
        name: 'مشاري راشد العفاسي',
        style: 'مرتل',
        folderName: 'surah-recitation-mishari-rashid-al-afasy',
      );

      final r2 = ReciterAudioModel(
        id: 'mishari_alafasy',
        name: 'مشاري راشد العفاسي (نسخة أخرى)',
        style: 'مرتل',
        folderName: 'surah-recitation-mishari-rashid-al-afasy',
      );

      final r3 = ReciterAudioModel(
        id: 'abdulbasit_murattal',
        name: 'عبد الباسط عبد الصمد',
        style: 'مرتل',
        folderName: 'surah-recitation-abdul-basit-abd-us-samad-murattal',
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });

    test('ReciterHighlightSupport correctly distinguishes word-by-word vs verse vs none', () {
      final wbwReciter = ReciterAudioModel(
        id: 'alnufais',
        name: 'أحمد النفيس',
        style: 'مرتل',
        folderName: 'surah-recitation-ahmad-alnufais',
        zipFileName: 'ayah-recitation-alnufais.json.zip',
        hasSegments: true,
      );
      expect(wbwReciter.highlightSupport, equals(ReciterHighlightSupport.wordByWord));

      final verseReciter = ReciterAudioModel(
        id: 'baleela',
        name: 'بندر بليلة',
        style: 'مرتل',
        folderName: 'surah-recitation-bandar-baleela',
        hasSegments: true,
      );
      expect(verseReciter.highlightSupport, equals(ReciterHighlightSupport.verseOnly));

      final noneReciter = ReciterAudioModel(
        id: 'kalbani',
        name: 'عادل الكلباني',
        style: 'مرتل',
        folderName: 'surah-recitation-adel-kalbani',
        hasSegments: false,
      );
      expect(noneReciter.highlightSupport, equals(ReciterHighlightSupport.none));
    });

    test('WordSegment fromList parses various segment representations correctly', () {
      final seg4 = WordSegment.fromList([1, 0, 150, 450]);
      expect(seg4.wordIndex, equals(1));
      expect(seg4.startMs, equals(150));
      expect(seg4.endMs, equals(450));

      final seg3 = WordSegment.fromList([2, 500, 950]);
      expect(seg3.wordIndex, equals(2));
      expect(seg3.startMs, equals(500));
      expect(seg3.endMs, equals(950));
    });

    test('VerseTiming.fromJson constructs segment intervals accurately', () {
      final json = {
        'timestamp_from': 100,
        'timestamp_to': 2500,
        'duration_ms': 2400,
        'segments': [
          [1, 0, 100, 800],
          [2, 0, 850, 1600],
          [3, 0, 1650, 2500],
        ]
      };

      final timing = VerseTiming.fromJson('1:1', json);
      expect(timing.surahNumber, equals(1));
      expect(timing.verseNumber, equals(1));
      expect(timing.timestampFrom, equals(100));
      expect(timing.timestampTo, equals(2500));
      expect(timing.durationMs, equals(2400));
      expect(timing.segments.length, equals(3));
      expect(timing.segments[1].startMs, equals(850));
    });

    test('getAyahAudioUrl builds valid CDN urls for EveryAyah', () {
      final reciter = ReciterAudioModel(
        id: 'mishari_alafasy',
        name: 'مشاري راشد العفاسي',
        style: 'مرتل',
        folderName: 'surah-recitation-mishari-rashid-al-afasy',
        everyAyahFolder: 'Alafasy_128kbps',
      );

      final url = ReciterAudioHelper.getAyahAudioUrl(1, 1, reciter);
      expect(url, equals('https://everyayah.com/data/Alafasy_128kbps/001001.mp3'));

      final url2 = ReciterAudioHelper.getAyahAudioUrl(114, 6, reciter);
      expect(url2, equals('https://everyayah.com/data/Alafasy_128kbps/114006.mp3'));
    });
  });
}
