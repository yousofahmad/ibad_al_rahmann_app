import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_export_service.dart';

void main() {
  test(
    'validation failure is diagnosed without recording selected content',
    () async {
      final events = <MapEntry<String, Map<String, Object?>>>[];
      final service = QuranVideoExportService(
        diagnosticSink: (event, fields) =>
            events.add(MapEntry(event, Map<String, Object?>.from(fields))),
      );

      await expectLater(
        service.export(
          reciter: ReciterAudioModel(
            id: 'test-reader',
            name: 'Test reader',
            style: 'murattal',
            folderName: 'test-reader',
          ),
          surahNumber: 0,
          fromVerse: 1,
          toVerse: 1,
          backgroundPath: 'unused',
          backgroundType: QuranVideoBackgroundType.image,
          options: const QuranVideoExportOptions(),
          onProgress: (_) {},
        ),
        throwsA(isA<QuranVideoExportException>()),
      );

      expect(events.any((entry) => entry.key == 'export_started'), isTrue);
      final failure = events.singleWhere(
        (entry) => entry.key == 'export_failed',
      );
      expect(failure.value['phase'], 'validate_request');
      expect(failure.value['reason'], 'export_exception');
      expect(failure.value.keys, isNot(contains('surah')));
      expect(failure.value.keys, isNot(contains('from_ayah')));
      expect(failure.value.keys, isNot(contains('to_ayah')));
      expect(failure.value.keys, isNot(contains('reader_id')));
      expect(events.any((entry) => entry.key == 'cleanup_finished'), isTrue);
    },
  );
}
