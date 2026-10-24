import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_pagination.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _run = bool.fromEnvironment('IBAD_RUN_LOCAL_RESOURCE_TESTS');
const _root = String.fromEnvironment('IBAD_LOCAL_RESOURCE_ROOT');
const _ids = <String>['qpc_v2_1421', 'qpc_v4_tajweed_1441'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real local Mushaf packages expose verified adapted navigation',
    () async {
      final root = FeatureResourceRepository(rootPath: _root);
      final catalog = await root.readJson('mushaf/catalog.json');
      expect(catalog, isNotNull);
      final packages = (catalog!['formats'] as List).whereType<Map>().toList();
      expect(packages.map((e) => e['id']), containsAll(_ids));

      final documents = await Directory.systemTemp.createTemp('mushaf_actual_');
      addTearDown(() async {
        if (await documents.exists()) await documents.delete(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = MushafFormatRepository(
        preferences: prefs,
        documentsDirectory: documents,
        resourceRepository: root,
      );
      await repository.initialize();
      await repository.refreshCatalog();
      expect(repository.current, MushafFormat.builtin);

      for (final id in _ids) {
        final raw = Map<String, dynamic>.from(
          packages.singleWhere((item) => item['id'] == id),
        );
        expect(raw['package_url'], 'mushaf/formats/$id.zip');
        expect(raw['pagination_matches_builtin'], isFalse);
        expect(raw['word_alignment_matches_builtin'], isTrue);
        expect(raw['navigation_index_file'], 'pagination.json');
        final bytes = await root.readBytes(raw['package_url'] as String);
        expect(bytes, isNotNull);
        expect(sha256.convert(bytes!).toString(), raw['sha256']);
        final archive = ZipDecoder().decodeBytes(bytes);
        expect(archive.length, 608);
        final names = archive.map((entry) => entry.name).toSet();
        expect(names, contains('pagination.json'));
        expect(names, contains('fonts/p1.ttf'));
        expect(names, contains('fonts/p604.ttf'));
        final manifest =
            jsonDecode(
                  utf8.decode(
                    archive.firstWhere((e) => e.name == 'manifest.json').content
                        as List<int>,
                  ),
                )
                as Map<String, dynamic>;
        final indexBytes =
            archive.firstWhere((e) => e.name == 'pagination.json').content
                as List<int>;
        expect(
          manifest['navigation_index_sha256'],
          sha256.convert(indexBytes).toString(),
        );
        final index = MushafPaginationIndex.fromJson(
          jsonDecode(utf8.decode(indexBytes)) as Map<String, dynamic>,
        );
        expect(index.pageData(1), isNotEmpty);
        expect(index.pageData(604), isNotEmpty);
        expect(index.pageForAyah(5, 77), 120);
        expect(index.pageForWord(5, 77, 1), isNotNull);

        final format = repository.formats.singleWhere((item) => item.id == id);
        expect(
          format.navigationIndexSha256,
          manifest['navigation_index_sha256'],
        );
        // A verified sidecar enables adapted pagination without claiming the
        // underlying page splits match the builtin 1405 layout.
        expect(
          format.compatible,
          isTrue,
          reason:
              '$id has word-aligned metadata and a SHA-256 verified '
              'navigation sidecar for its non-builtin page splits',
        );
        await repository.install(id);
        await repository.select(id);
        expect(repository.current.id, id);
        expect(MushafPagination.pageForAyah(5, 77), 120);
        await repository.select(MushafFormat.builtin.id);
        expect(repository.current.isBuiltin, isTrue);
        await repository.select(id);
        expect(repository.current.id, id);
      }

      final restarted = MushafFormatRepository(
        preferences: prefs,
        documentsDirectory: documents,
        resourceRepository: root,
      );
      await restarted.initialize();
      expect(restarted.current.id, _ids.last);
    },
    skip: !_run || _root.trim().isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
