import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/background_resource_download_service.dart';

void main() {
  group('BackgroundResourceDownloadService.buildTask', () {
    test('creates a resumable task in the shared resource group', () {
      final task = BackgroundResourceDownloadService.buildTask(
        taskId: 'resource_test_1',
        id: 'audio:reader:1',
        url: 'https://example.org/ayah.mp3',
        filename: 'ayah.mp3.part',
        directory: 'quran/audio',
        baseDirectory: BaseDirectory.applicationSupport,
        displayName: 'تلاوة الآية',
        retries: 3,
      );

      expect(task.taskId, 'resource_test_1');
      expect(task.url, 'https://example.org/ayah.mp3');
      expect(task.filename, 'ayah.mp3.part');
      expect(task.directory, 'quran/audio');
      expect(task.baseDirectory, BaseDirectory.applicationSupport);
      expect(task.group, BackgroundResourceDownloadService.group);
      expect(task.metaData, 'audio:reader:1');
      expect(task.displayName, 'تلاوة الآية');
      expect(task.updates, Updates.statusAndProgress);
      expect(task.allowPause, isTrue);
      expect(task.retries, 3);
    });
  });
}
