import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_audio/data/models/surah_audio_model.dart';

void main() {
  test('parses string chapter and duration values from remote audio JSON', () {
    final model = SurahAudioModel.fromJson({
      'chapter_id': '2',
      'audio_url': null,
      'duration': '143',
    });

    expect(model.surahNumber, 2);
    expect(model.durationSec, 143);
    expect(model.url, isEmpty);
  });

  test(
    'uses safe defaults for missing or malformed numeric audio metadata',
    () {
      final model = SurahAudioModel.fromJson({
        'surah_number': 'not-a-number',
        'duration': null,
      });

      expect(model.surahNumber, 1);
      expect(model.durationSec, 0);
    },
  );
}
