import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _formatId = 'qpc_v2_1421';
const _packagePath = 'mushaf/formats/$_formatId.zip';
const _fontPrefix = 'IBAD_QPC_V2_P';
const _sqliteMagic = <int>[
  83,
  81,
  76,
  105,
  116,
  101,
  32,
  102,
  111,
  114,
  109,
  97,
  116,
  32,
  51,
  0,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late Directory resources;
  late SharedPreferences preferences;
  late Uint8List validZip;
  late String validHash;
  var completed = 0;
  final audit = <String>[];

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('mushaf_documents_');
    resources = await Directory.systemTemp.createTemp('mushaf_resources_');
    preferences = await _preferences({});
    validZip = _makeZip();
    validHash = sha256.convert(validZip).toString();
    await _writePackage(resources, validZip);
    await _writeCatalog(resources, _catalog(hash: validHash));
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
    if (await resources.exists()) await resources.delete(recursive: true);
  });

  tearDownAll(() async {
    await Directory(
      '/workspace/ibad_resource_audit/local_import',
    ).create(recursive: true);
    final log = File(
      '/workspace/ibad_resource_audit/local_import/mushaf-format-install-tests.log',
    );
    await log.writeAsString(
      'mushaf format install tests completed=$completed\n${audit.join('\n')}',
      flush: true,
    );
  });

  MushafFormatRepository repository({
    SharedPreferences? prefs,
    Directory? docs,
    Directory? root,
  }) {
    return MushafFormatRepository(
      preferences: prefs ?? preferences,
      documentsDirectory: docs ?? documents,
      resourceRepository: FeatureResourceRepository(
        rootPath: (root ?? resources).path,
      ),
    );
  }

  Future<MushafFormatRepository> initialized({
    SharedPreferences? prefs,
    Directory? docs,
    Directory? root,
  }) async {
    final value = repository(prefs: prefs, docs: docs, root: root);
    await value.initialize();
    await value.refreshCatalog();
    return value;
  }

  test(
    'valid package installs, selects, persists, and survives a new repository',
    () async {
      final first = await initialized();
      await first.install(_formatId);
      await first.select(_formatId);

      expect(first.current.id, _formatId);
      expect(first.fontFamily(17), 'IBAD_QPC_V2_1421_P17');
      expect(first.pageFontPath(604), endsWith('fonts/p604.ttf'));
      expect(first.getActiveWordsDatabasePath, endsWith('words.sqlite'));
      expect(first.getActiveLayoutDatabasePath, endsWith('layout.sqlite'));
      expect(first.isInstalled(_formatId), isTrue);

      final restarted = await initialized();
      expect(restarted.current.id, _formatId);
      expect(restarted.fontFamily(1), 'IBAD_QPC_V2_1421_P1');
      expect(restarted.pageFontPath(604), isNotNull);
      completed++;
    },
  );

  test('built-in defaults remain unchanged before installation', () async {
    final value = await initialized();
    expect(value.current.id, 'qpc_v1_builtin');
    expect(value.current.isBuiltin, isTrue);
    expect(value.fontFamily(17), 'QCF_V1_P17');
    expect(value.pageFontPath(17), isNull);
    expect(value.getActiveWordsDatabasePath, isNull);
    expect(value.getActiveLayoutDatabasePath, isNull);
    completed++;
  });

  test(
    'bad SHA preserves the built-in selection and leaves no marker or staging',
    () async {
      final badZip = _makeZip(fonts: false);
      await _writePackage(resources, badZip);
      final value = await initialized();

      expect(() => value.install(_formatId), throwsStateError);
      expect(value.current.id, 'qpc_v1_builtin');
      expect(value.isInstalled(_formatId), isFalse);
      expect(await _markerExists(documents), isFalse);
      expect(await _stagingDirectories(documents), isEmpty);
      completed++;
    },
  );

  test('bad package cannot replace a previously active installation', () async {
    final value = await initialized();
    await value.install(_formatId);
    await value.select(_formatId);
    await _writePackage(resources, _makeZip(fonts: false));

    expect(() => value.install(_formatId), throwsStateError);
    expect(value.current.id, _formatId);
    expect(value.pageFontPath(1), isNotNull);
    expect(await _markerExists(documents), isTrue);
    completed++;
  });

  test('path traversal member is rejected without extraction', () async {
    final zip = _makeZip(extra: ArchiveFile('../escape.txt', 1, <int>[1]));
    await _writePackage(resources, zip);
    final value = await initialized();

    expect(() => value.install(_formatId), throwsStateError);
    expect(File('${documents.path}/escape.txt').existsSync(), isFalse);
    expect(await _markerExists(documents), isFalse);
    completed++;
  });

  test('missing font member is rejected without a completion marker', () async {
    final zip = _makeZip(missingFont: 604);
    await _writePackage(resources, zip);
    final value = await initialized();

    expect(() => value.install(_formatId), throwsStateError);
    expect(await _markerExists(documents), isFalse);
    completed++;
  });

  test('duplicate ZIP member is rejected', () async {
    final zip = _makeZip(extra: ArchiveFile('manifest.json', 1, <int>[1]));
    await _writePackage(resources, zip);
    final value = await initialized();

    expect(() => value.install(_formatId), throwsStateError);
    expect(await _markerExists(documents), isFalse);
    completed++;
  });

  test(
    'simultaneous installs are single-flight and both callers complete',
    () async {
      final value = await initialized();
      final first = value.install(_formatId);
      final second = value.install(_formatId);

      await Future.wait<void>(<Future<void>>[first, second]);
      expect(value.isInstalled(_formatId), isTrue);
      expect(await _markerExists(documents), isTrue);
      expect(await _stagingDirectories(documents), isEmpty);
      audit.add('single-flight concurrent install completed without errors');
      completed++;
    },
  );

  test(
    'invalid IDs and foreign package URLs are rejected by the catalog',
    () async {
      final invalid = _catalog(
        hash: validHash,
      ).replaceFirst('"id":"$_formatId"', '"id":"../escape"');
      await _writeCatalog(resources, invalid);
      final value = await initialized();

      expect(value.formats, hasLength(1));
      expect(value.current.id, 'qpc_v1_builtin');
      expect(() => value.install('../escape'), throwsStateError);

      await _writeCatalog(
        resources,
        _catalog(hash: validHash, url: 'https://evil.example/$_formatId.zip'),
      );
      final refreshed = await initialized(prefs: preferences);
      expect(refreshed.formats, hasLength(1));
      completed++;
    },
  );

  test('malformed local catalog keeps the previous cached catalog', () async {
    final value = await initialized();
    expect(value.formats.map((format) => format.id), contains(_formatId));
    await value.refreshCatalog();
    expect(value.formats.map((format) => format.id), contains(_formatId));

    await _writeCatalog(resources, '{"schema_version":1,"formats":"broken"');
    await value.refreshCatalog();
    expect(value.formats.map((format) => format.id), contains(_formatId));
    expect(value.formats, hasLength(2));
    completed++;
  });

  test(
    'an installed package missing a font is rejected after restart',
    () async {
      final value = await initialized();
      await value.install(_formatId);
      await value.select(_formatId);
      await File(
        '${documents.path}/mushaf_formats/$_formatId/fonts/p604.ttf',
      ).delete();

      final restarted = await initialized();
      expect(restarted.current.id, 'qpc_v1_builtin');
      expect(restarted.isInstalled(_formatId), isFalse);
      completed++;
    },
  );
}

Future<SharedPreferences> _preferences(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

String _catalog({required String hash, String url = _packagePath}) =>
    jsonEncode({
      'schema_version': 1,
      'formats': [
        {
          'id': _formatId,
          'name': 'QPC v2',
          'description': 'Test package',
          'page_count': 604,
          'line_count': 15,
          'has_tajweed': false,
          'package_url': url,
          'sha256': hash,
          'size_bytes': 0,
          'pagination_matches_builtin': true,
          'word_alignment_matches_builtin': true,
        },
      ],
    });

Uint8List _makeZip({int? missingFont, bool fonts = true, ArchiveFile? extra}) {
  final archive = Archive();
  final manifest = jsonEncode({
    'schema_version': 1,
    'id': _formatId,
    'page_count': 604,
    'line_count': 15,
    'pagination_matches_builtin': true,
    'word_alignment_matches_builtin': true,
    'font_family_prefix': _fontPrefix,
  });
  archive.addFile(
    ArchiveFile(
      'manifest.json',
      utf8.encode(manifest).length,
      utf8.encode(manifest),
    ),
  );
  archive.addFile(
    ArchiveFile('words.sqlite', _sqliteMagic.length + 5, <int>[
      ..._sqliteMagic,
      1,
      2,
      3,
      4,
      5,
    ]),
  );
  archive.addFile(
    ArchiveFile('layout.sqlite', _sqliteMagic.length + 5, <int>[
      ..._sqliteMagic,
      6,
      7,
      8,
      9,
      0,
    ]),
  );
  if (fonts) {
    for (var page = 1; page <= 604; page++) {
      if (page == missingFont) continue;
      archive.addFile(
        ArchiveFile('fonts/p$page.ttf', 8, <int>[0, 1, 0, 0, 0, 0, 0, 0]),
      );
    }
  }
  if (extra != null) archive.addFile(extra);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<void> _writePackage(Directory root, Uint8List bytes) async {
  final file = File('${root.path}/$_packagePath');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _writeCatalog(Directory root, String catalog) async {
  final file = File('${root.path}/mushaf/catalog.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(catalog, flush: true);
}

Future<bool> _markerExists(Directory documents) =>
    File('${documents.path}/mushaf_formats/$_formatId/.complete').exists();

Future<List<FileSystemEntity>> _stagingDirectories(Directory documents) async {
  final base = Directory('${documents.path}/mushaf_formats');
  if (!await base.exists()) return <FileSystemEntity>[];
  return base
      .listSync()
      .where((entry) => entry.path.contains('.$_formatId.staging.'))
      .toList();
}
