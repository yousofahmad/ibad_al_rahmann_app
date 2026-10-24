import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('tafsir_cache_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documents.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  Future<Directory> cachedBook(
    String id,
    Map<int, Map<int, String>> surahs, {
    bool complete = true,
  }) async {
    final directory = Directory('${documents.path}/tafseer/$id');
    await directory.create(recursive: true);
    for (final surah in surahs.entries) {
      await File('${directory.path}/${surah.key}.json').writeAsString(
        json.encode({
          'ayahs': [
            for (final ayah in surah.value.entries)
              {'ayah': ayah.key, 'text': ayah.value},
          ],
        }),
      );
    }
    if (complete) {
      await File('${directory.path}/.complete').writeAsString('done');
    }
    return directory;
  }

  test(
    'completed download is returned intact without touching source files',
    () async {
      const id = 'preserve_completed_en';
      final directory = await cachedBook(id, {
        1: {1: 'Existing full text'},
      });
      final marker = File('${directory.path}/.complete');
      final surah = File('${directory.path}/1.json');
      final originalMarker = await marker.readAsBytes();
      final originalSurah = await surah.readAsBytes();
      var completions = 0;
      bool? success;

      await TafsirHelper.downloadBook(
        const TafsirBook(
          id: id,
          name: 'Fixture',
          author: 'Fixture',
          isBuiltIn: false,
          languageCode: 'en',
          size: '1 KB',
          // Invalid by design: an installed book must not perform any network I/O.
          url: 'unsafe/path',
        ),
        onProgress: (_) {},
        onComplete: (value, _) {
          completions++;
          success = value;
        },
      );

      expect(success, isTrue);
      expect(completions, 1);
      expect(await marker.readAsBytes(), originalMarker);
      expect(await surah.readAsBytes(), originalSurah);
      expect(await directory.list().length, 2);
    },
  );

  test(
    'legacy cache resolves chained cross-surah references without slicing',
    () async {
      const id = 'legacy_cross_chain_en';
      const passage = 'English [1] /(1)/ full shared passage';
      await cachedBook(id, {
        1: {1: '1:2', 2: '2:3'},
        2: {3: passage},
      });

      await TafsirHelper.loadSurahTafsir(id, 1);
      expect(TafsirHelper.getVerseTafsir(1, 1, bookId: id), passage);
      expect(TafsirHelper.getVerseTafsir(1, 2, bookId: id), passage);
      expect(TafsirHelper.getVerseTafsir(2, 3, bookId: id), passage);
    },
  );

  test(
    'legacy cycles and missing targets leave other tafsir readable',
    () async {
      const id = 'legacy_cycle_and_missing';
      await cachedBook(id, {
        1: {1: '2:2', 2: 'Preserved', 3: '3:1'},
        2: {2: '1:1'},
      });

      await TafsirHelper.loadSurahTafsir(id, 1);
      expect(TafsirHelper.getVerseTafsir(1, 1, bookId: id), isEmpty);
      expect(TafsirHelper.getVerseTafsir(1, 2, bookId: id), 'Preserved');
      expect(TafsirHelper.getVerseTafsir(1, 3, bookId: id), isEmpty);
    },
  );

  test(
    'an incomplete import stays unavailable until its complete marker exists',
    () async {
      const id = 'incomplete_then_completed';
      final directory = await cachedBook(id, {
        1: {1: 'Not partial'},
      }, complete: false);

      await TafsirHelper.loadSurahTafsir(id, 1);
      expect(TafsirHelper.getVerseTafsir(1, 1, bookId: id), isEmpty);
      expect(await TafsirHelper.isBookDownloaded(id), isFalse);

      await File('${directory.path}/.complete').writeAsString('done');
      await TafsirHelper.loadSurahTafsir(id, 1);
      expect(TafsirHelper.getVerseTafsir(1, 1, bookId: id), 'Not partial');
      expect(await TafsirHelper.isBookDownloaded(id), isTrue);
    },
  );
}
