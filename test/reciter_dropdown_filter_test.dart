import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/audio/reciter_dropdown.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

void main() {
  ReciterAudioModel reciter({
    required String id,
    required String name,
    required String category,
    bool hasSegments = true,
    String? zipFileName,
  }) {
    return ReciterAudioModel(
      id: id,
      name: name,
      style: 'مرتل',
      folderName: 'surah-$id',
      category: category,
      hasSegments: hasSegments,
      zipFileName: zipFileName,
    );
  }

  final wordByWord = reciter(
    id: 'word',
    name: 'قارئ الكلمات',
    category: 'مشاهير القراء',
    zipFileName: 'segments.zip',
  );
  final verseOnly = reciter(
    id: 'verse',
    name: 'قارئ الآيات',
    category: 'أئمة الحرمين الشريفين',
  );
  final surahOnly = reciter(
    id: 'surah',
    name: 'قارئ السورة',
    category: 'مشاهير القراء',
    hasSegments: false,
  );

  test('filters unsupported capabilities without capability badges', () {
    final all = [wordByWord, verseOnly, surahOnly];

    expect(ReciterDropdown.filterReciters(reciters: all, wordByWord: true), [
      wordByWord,
    ]);
    expect(ReciterDropdown.filterReciters(reciters: all, wordByWord: false), [
      wordByWord,
      verseOnly,
    ]);
  });

  test(
    'keeps category and search filters in addition to capability filtering',
    () {
      expect(
        ReciterDropdown.filterReciters(
          reciters: [wordByWord, verseOnly, surahOnly],
          wordByWord: false,
          category: 'أئمة الحرمين الشريفين',
          searchQuery: 'الآيات',
        ),
        [verseOnly],
      );
    },
  );

  test(
    'supports explicit full-surah mode independently of highlighting modes',
    () {
      expect(
        ReciterDropdown.filterReciters(
          reciters: [wordByWord, verseOnly, surahOnly],
          mode: ReciterAudioMode.fullSurah,
        ),
        [wordByWord, verseOnly, surahOnly],
      );
      expect(
        ReciterDropdown.filterReciters(
          reciters: [wordByWord, verseOnly, surahOnly],
          mode: ReciterAudioMode.wordByWord,
        ),
        [wordByWord],
      );
    },
  );
}
