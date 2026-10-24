import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy reciters retain default local fields and capabilities', () {
    final legacy = ReciterAudioHelper.defaultReciters.first;
    expect(legacy.localOnly, isFalse);
    expect(legacy.hasSurahAudio, isTrue);
    expect(legacy.supportsFullSurah, isTrue);
  });

  test('ZIP metadata supports ayah mode without word segments', () {
    final local = ReciterAudioModel(
      id: 'local_reader',
      name: 'Local',
      style: 'مرتل',
      folderName: 'surah-recitation-local-reader',
      localOnly: true,
      hasSegments: false,
      hasSurahAudio: false,
      zipFileName: 'ayah.json.zip',
    );
    expect(local.supportsAyahByAyah, isTrue);
    expect(local.supportsWordByWord, isFalse);
    expect(local.supportsFullSurah, isFalse);
  });

  test('unverified local download fails safely with one completion', () async {
    var completions = 0;
    bool? success;
    await ReciterAudioHelper.downloadSurah(
      'surah-recitation-local-reader',
      1,
      'file:///outside-configured-root.mp3',
      onProgress: (_) => fail('Unverified files must not be copied'),
      onComplete: (value, error) {
        completions++;
        success = value;
        expect(error, isNotEmpty);
      },
    );
    expect(completions, 1);
    expect(success, isFalse);
  });

  test(
    'resource repository rejects traversal and accepts a verified file',
    () async {
      final root = await Directory.systemTemp.createTemp('reciter-local-test');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/audio/test.mp3')
        ..createSync(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      final repo = FeatureResourceRepository(rootPath: root.path);
      expect(await repo.readBytes('../audio/test.mp3'), isNull);
      expect(await repo.fileUri('audio/test.mp3'), isNotNull);
    },
  );
}
