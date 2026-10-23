import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/logic/quran_readers_cubit.dart';

void main() {
  final reciters = [
    ReciterAudioModel(
      id: 'words',
      name: 'قارئ كلمات',
      style: 'مرتل',
      folderName: 'words',
      zipFileName: 'words.zip',
      category: 'مصر',
    ),
    ReciterAudioModel(
      id: 'verses',
      name: 'قارئ آيات',
      style: 'مجود',
      folderName: 'verses',
      category: 'مصر',
    ),
    ReciterAudioModel(
      id: 'surah',
      name: 'قارئ سورة',
      style: 'مرتل',
      folderName: 'surah',
      hasSegments: false,
    ),
    ReciterAudioModel(
      id: 'ayah-only',
      name: 'قارئ آية فقط',
      style: 'مرتل',
      folderName: '',
      hasSegments: true,
    ),
    ReciterAudioModel(
      id: 'words-and-ayah',
      name: 'قارئ كلمات وآيات فقط',
      style: 'مرتل',
      folderName: '',
      hasSegments: true,
      zipFileName: 'words-only.zip',
    ),
    ReciterAudioModel(
      id: 'ayah-audio-only',
      name: 'قارئ آيات بلا تظليل',
      style: 'مرتل',
      folderName: '',
      everyAyahFolder: 'verse-recordings',
      hasSegments: false,
    ),
  ];

  List<String> filter(QuranReciterFilter mode, [String query = '']) =>
      QuranReadersCubit.filterReciters(
        reciters: reciters,
        filter: mode,
        query: query,
      ).map((r) => r.id).toList();

  test(
    'capability filters only include reciters supporting the selected option',
    () {
      expect(filter(QuranReciterFilter.wordByWord), [
        'words',
        'words-and-ayah',
      ]);
      expect(filter(QuranReciterFilter.verseOnly), [
        'words',
        'verses',
        'ayah-only',
        'words-and-ayah',
        'ayah-audio-only',
      ]);
      expect(filter(QuranReciterFilter.surah), ['words', 'verses', 'surah']);
    },
  );

  test('catalog readers with EveryAyah but no timings support ayah audio', () {
    final kalbani = ReciterAudioHelper.defaultReciters.firstWhere(
      (reciter) => reciter.id == 'kalbani',
    );
    expect(kalbani.supportsWordByWord, isFalse);
    expect(kalbani.supportsAyahByAyah, isTrue);
    expect(kalbani.supportsFullSurah, isTrue);
  });

  test(
    'search is intersected with capability and matches name, style, and category',
    () {
      expect(filter(QuranReciterFilter.wordByWord, 'سورة'), isEmpty);
      expect(filter(QuranReciterFilter.verseOnly, ' مجود '), ['verses']);
      expect(filter(QuranReciterFilter.surah, 'مصر'), ['words', 'verses']);
    },
  );
}
