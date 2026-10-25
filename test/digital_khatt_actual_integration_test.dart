import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_pagination.dart';
import 'package:ibad_al_rahmann/core/helpers/optional_mushaf_playback_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runLocal = bool.fromEnvironment('IBAD_RUN_LOCAL_RESOURCE_TESTS');
const _runPublic = bool.fromEnvironment('IBAD_RUN_PUBLIC_RESOURCE_TESTS');
const _root = String.fromEnvironment('IBAD_LOCAL_RESOURCE_ROOT');
const _output = String.fromEnvironment('IBAD_RESOURCE_TEST_OUTPUT');
const _id = 'digital_khatt_v2';

// The Flutter test binding otherwise replaces HTTP with mock status 400.
class _PublicNetworkOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => MushafPagination.activate(null));

  test(
    'real Digital Khatt package installs, follows canonical words and survives offline restart',
    () async {
      final resources = FeatureResourceRepository(rootPath: _root);
      final catalog = await resources.readJson('mushaf/catalog-v2.json');
      final proof = await resources.readJson(
        'mushaf/digital_khatt_v2_proof.json',
      );
      expect(catalog, isNotNull);
      expect(proof, isNotNull);
      final raw = Map<String, dynamic>.from(
        (catalog!['formats'] as List).whereType<Map>().singleWhere(
          (e) => e['id'] == _id,
        ),
      );
      final bytes = await resources.readBytes('mushaf/formats/$_id.zip');
      expect(bytes, isNotNull);
      expect(sha256.convert(bytes!).toString(), raw['sha256']);
      final archive = ZipDecoder().decodeBytes(bytes);
      final entries = {for (final entry in archive) entry.name: entry};
      expect(entries.keys.toSet(), {
        'manifest.json',
        'words.sqlite',
        'layout.sqlite',
        'pagination.json',
        'fonts/quran.otf',
        'LICENSE.txt',
      });
      Uint8List content(String name) =>
          Uint8List.fromList(entries[name]!.content as List<int>);
      expect(
        sha256.convert(content('fonts/quran.otf')).toString(),
        proof!['font_sha256'],
      );
      expect(
        sha256.convert(content('LICENSE.txt')).toString(),
        raw['license_sha256'],
      );
      expect(
        utf8.decode(content('LICENSE.txt')),
        contains('SIL OPEN FONT LICENSE Version 1.1'),
      );
      expect(
        utf8.decode(content('LICENSE.txt')),
        isNot(contains('<Copyright Holder>')),
      );
      final indexJson =
          jsonDecode(utf8.decode(content('pagination.json')))
              as Map<String, dynamic>;
      final index = MushafPaginationIndex.fromJson(indexJson);
      expect((indexJson['verses'] as Map).length, 6236);
      expect(proof['canonical_word_rows'], 83668);
      expect(proof['all_canonical_words_placed_once'], isTrue);

      final documents = await Directory.systemTemp.createTemp(
        'digital_khatt_actual_',
      );
      addTearDown(() => documents.delete(recursive: true));
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = MushafFormatRepository(
        preferences: preferences,
        documentsDirectory: documents,
        resourceRepository: resources,
      );
      await repository.initialize();
      await repository.refreshCatalog();
      final format = repository.formats.singleWhere((e) => e.id == _id);
      expect(format.compatible, isTrue);
      expect(format.isUnicodeFont, isTrue);
      await repository.install(_id);
      expect(
        repository.current.isBuiltin,
        isTrue,
        reason: 'Download must never change the default',
      );
      await repository.select(_id);
      expect(repository.fontFamily(1), repository.fontFamily(604));
      expect(repository.pageFontPath(1), repository.pageFontPath(604));
      expect(repository.pageFontPath(604), endsWith('fonts/quran.otf'));
      expect(
        FontsHelper.sameFormatFamily(repository.fontFamily(1), 'QCF_V1_P1'),
        isFalse,
      );
      expect(MushafPagination.pageCount, 604);
      expect(MushafPagination.lineCount, 15);
      for (var page = 1; page <= 604; page++) {
        expect(
          MushafPagination.pageData(page),
          isNotEmpty,
          reason: 'page $page',
        );
      }
      for (final verse in (indexJson['words'] as Map).entries) {
        final coordinate = verse.key
            .toString()
            .split(':')
            .map(int.parse)
            .toList();
        for (final word in (verse.value as Map).entries) {
          expect(
            MushafPagination.pageForWord(
              coordinate[0],
              coordinate[1],
              int.parse(word.key.toString()),
            ),
            word.value,
          );
        }
      }
      expect(
        OptionalMushafPlaybackNavigation.targetPageIndex(
          surah: 5,
          ayah: 77,
          currentPageIndex: 0,
          oneBasedWordPosition: 1,
          followWords: true,
          pageCount: 604,
          pageForAyah: MushafPagination.pageForAyah,
          pageForWord: MushafPagination.pageForWord,
          pageContainsAyah: MushafPagination.pageContainsAyah,
        ),
        119,
      );
      expect(
        OptionalMushafPlaybackNavigation.targetPageIndex(
          surah: 5,
          ayah: 77,
          currentPageIndex: 119,
          oneBasedWordPosition: null,
          followWords: true,
          pageCount: 604,
          pageForAyah: MushafPagination.pageForAyah,
          pageForWord: MushafPagination.pageForWord,
          pageContainsAyah: MushafPagination.pageContainsAyah,
        ),
        119,
      );
      // A bookmark/verse anchor resolves through selected pagination, not a
      // copied 1405 page number. Switching back preserves the original API.
      expect(MushafPagination.pageForAyah(5, 77), 120);
      await repository.select(MushafFormat.builtin.id);
      expect(repository.fontFamily(1), 'QCF_V1_P1');
      expect(MushafPagination.previousPageForAyah(5, 77), 120);
      await repository.select(_id);
      final installedFont = File(repository.pageFontPath(1)!);
      final beforeRestart = sha256
          .convert(await installedFont.readAsBytes())
          .toString();
      final restarted = MushafFormatRepository(
        preferences: preferences,
        documentsDirectory: documents,
        resourceRepository: FeatureResourceRepository(rootPath: ''),
      );
      await restarted.initialize();
      expect(restarted.current.id, _id);
      expect(restarted.current.fontMode, 'unicode_single');
      expect(restarted.current.licenseSha256, raw['license_sha256']);
      expect(restarted.isInstalled(_id), isTrue);
      expect(
        sha256
            .convert(await File(restarted.pageFontPath(604)!).readAsBytes())
            .toString(),
        beforeRestart,
      );
      expect(MushafPagination.pageForAyah(114, 6), 604);
      expect(index.pageForAyah(2, 255), 42);
    },
    skip: !_runLocal || _root.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'actual packaged original Digital Khatt font rasterizes Quran glyphs natively',
    () async {
      final resources = FeatureResourceRepository(rootPath: _root);
      final bytes = (await resources.readBytes('mushaf/formats/$_id.zip'))!;
      final archive = ZipDecoder().decodeBytes(bytes);
      final font = Uint8List.fromList(
        archive.firstWhere((e) => e.name == 'fonts/quran.otf').content
            as List<int>,
      );
      final loader = FontLoader('IBAD_DIGITAL_KHATT_RENDER_PROBE_P1')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(font)));
      await loader.load();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      final painter = TextPainter(
        text: const TextSpan(
          text: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          style: TextStyle(
            fontFamily: 'IBAD_DIGITAL_KHATT_RENDER_PROBE_P1',
            fontSize: 48,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: 700);
      expect(painter.width, greaterThan(200));
      painter.paint(canvas, const Offset(24, 24));
      final image = await recorder.endRecording().toImage(760, 150);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png!.lengthInBytes, greaterThan(1000));
      if (_output.isNotEmpty) {
        final directory = Directory(_output);
        await directory.create(recursive: true);
        await File(
          '$_output/digital_khatt_packaged_font.png',
        ).writeAsBytes(png.buffer.asUint8List());
      }
      painter.dispose();
      image.dispose();
    },
    skip: !_runLocal || _root.isEmpty,
  );

  test(
    'public versioned catalog and real package download install without QUL login',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final documents = await Directory.systemTemp.createTemp(
        'digital_khatt_public_',
      );
      addTearDown(() => documents.delete(recursive: true));
      SharedPreferences.setMockInitialValues({});
      final repository = MushafFormatRepository(
        preferences: await SharedPreferences.getInstance(),
        documentsDirectory: documents,
        resourceRepository: FeatureResourceRepository(rootPath: ''),
      );
      await repository.initialize();
      await repository.refreshCatalog();
      expect(
        repository.formats.any((e) => e.id == _id && e.compatible),
        isTrue,
      );
      await repository.install(_id);
      expect(repository.current.isBuiltin, isTrue);
      await repository.select(_id);
      expect(repository.current.id, _id);
      expect(repository.pageFontPath(604), endsWith('fonts/quran.otf'));
      expect(MushafPagination.pageForAyah(5, 77), 120);
    }, _PublicNetworkOverrides()),
    skip: !_runPublic,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
