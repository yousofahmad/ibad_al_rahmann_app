import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = 'digital_khatt_v2';
const _packagePath = 'mushaf/formats/$_id.zip';
const _prefix = 'IBAD_DIGITAL_KHATT_V2_P';
const _sqlite = <int>[
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
  late SharedPreferences prefs;
  late Uint8List package;
  late String packageHash;
  const license = 'Digital Khatt fixture license';
  final licenseHash = sha256.convert(utf8.encode(license)).toString();

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('unicode_documents_');
    resources = await Directory.systemTemp.createTemp('unicode_resources_');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    package = _zip(license: license);
    packageHash = sha256.convert(package).toString();
    await _writePackage(resources, package);
    await _writeCatalog(
      resources,
      _catalog(sha256: packageHash, licenseSha256: licenseHash),
    );
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
    if (await resources.exists()) await resources.delete(recursive: true);
  });

  MushafFormatRepository repo({
    SharedPreferences? preferences,
    Directory? docs,
  }) => MushafFormatRepository(
    preferences: preferences ?? prefs,
    documentsDirectory: docs ?? documents,
    resourceRepository: FeatureResourceRepository(rootPath: resources.path),
  );

  Future<bool> installedDirectoryExists() =>
      Directory('${documents.path}/mushaf_formats/$_id').exists();

  Future<MushafFormatRepository> initialized({
    SharedPreferences? preferences,
    Directory? docs,
  }) async {
    final value = repo(preferences: preferences, docs: docs);
    await value.initialize();
    await value.refreshCatalog();
    return value;
  }

  test('valid Unicode package installs but does not auto-select', () async {
    final value = await initialized();
    expect(value.current, MushafFormat.builtin);
    final format = value.formats.singleWhere((item) => item.id == _id);
    expect(format.fontMode, 'unicode_single');
    expect(format.licenseSha256, licenseHash);
    expect(format.isUnicodeFont, isTrue);
    await value.install(_id);
    expect(value.current.id, MushafFormat.builtin.id);
    expect(value.isInstalled(_id), isTrue);
  });

  test(
    'Unicode selection uses one quran font and the expected family on pages 1 and 604',
    () async {
      final value = await initialized();
      await value.install(_id);
      await value.select(_id);
      expect(value.current.id, _id);
      expect(value.fontFamily(1), '${_prefix}1');
      expect(value.fontFamily(604), '${_prefix}1');
      expect(value.pageFontPath(1), endsWith('fonts/quran.otf'));
      expect(value.pageFontPath(604), endsWith('fonts/quran.otf'));
      expect(value.getActiveWordsDatabasePath, endsWith('words.sqlite'));
      expect(value.getActiveLayoutDatabasePath, endsWith('layout.sqlite'));
    },
  );

  test(
    'selected Unicode mode, license, and installed files survive restart',
    () async {
      final value = await initialized();
      await value.install(_id);
      await value.select(_id);
      final restarted = await initialized();
      expect(restarted.current.id, _id);
      expect(restarted.current.licenseSha256, licenseHash);
      expect(restarted.pageFontPath(604), endsWith('fonts/quran.otf'));
      expect(
        File('${documents.path}/mushaf_formats/$_id/LICENSE.txt').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'built-in defaults remain unchanged before Unicode installation',
    () async {
      final value = await initialized();
      expect(value.current.id, 'qpc_v1_builtin');
      expect(value.current.fontMode, 'page_glyph');
      expect(value.current.isUnicodeFont, isFalse);
      expect(value.fontFamily(1), 'QCF_V1_P1');
      expect(value.pageFontPath(1), isNull);
    },
  );

  test('missing license is rejected', () async {
    await _writePackage(resources, _zip(license: null));
    final value = await initialized();
    expect(() => value.install(_id), throwsStateError);
    expect(value.current.id, 'qpc_v1_builtin');
    expect(await installedDirectoryExists(), isFalse);
  });

  test('wrong license content hash is rejected', () async {
    await _writeCatalog(
      resources,
      _catalog(sha256: packageHash, licenseSha256: 'a' * 64),
    );
    final value = await initialized();
    expect(() => value.install(_id), throwsStateError);
    expect(await installedDirectoryExists(), isFalse);
  });

  test('manifest font mode mismatch is rejected', () async {
    await _writePackage(
      resources,
      _zip(license: license, manifestMode: 'page_glyph'),
    );
    final value = await initialized();
    expect(() => value.install(_id), throwsStateError);
  });

  test(
    'malformed or missing Unicode license hash and unknown mode are rejected from catalog',
    () async {
      for (final entry in <Map<String, dynamic>>[
        <String, dynamic>{
          'font_mode': 'unicode_single',
          'license_sha256': 'bad',
        },
        <String, dynamic>{'font_mode': 'unicode_single'},
        <String, dynamic>{
          'font_mode': 'mystery',
          'license_sha256': licenseHash,
        },
      ]) {
        await _writeCatalog(
          resources,
          _catalog(sha256: packageHash, extra: entry),
        );
        final value = await initialized();
        expect(value.formats, hasLength(1));
        expect(value.current.id, 'qpc_v1_builtin');
      }
    },
  );

  test(
    'unexpected legacy font member is rejected for Unicode package',
    () async {
      await _writePackage(
        resources,
        _zip(
          license: license,
          extra: ArchiveFile('fonts/p1.ttf', 4, <int>[0, 1, 0, 0]),
        ),
      );
      final value = await initialized();
      expect(() => value.install(_id), throwsStateError);
      expect(await installedDirectoryExists(), isFalse);
    },
  );

  test(
    'tampered license on restart falls back without deleting installation',
    () async {
      final value = await initialized();
      await value.install(_id);
      await value.select(_id);
      final licenseFile = File(
        '${documents.path}/mushaf_formats/$_id/LICENSE.txt',
      );
      await licenseFile.writeAsString('tampered', flush: true);
      final restarted = await initialized();
      expect(restarted.current.id, 'qpc_v1_builtin');
      expect(restarted.isInstalled(_id), isFalse);
      expect(await installedDirectoryExists(), isTrue);
      expect(await licenseFile.readAsString(), 'tampered');
    },
  );

  test('Unicode package cannot omit word alignment compatibility', () async {
    await _writeCatalog(
      resources,
      _catalog(
        sha256: packageHash,
        licenseSha256: licenseHash,
        wordAlignment: false,
      ),
    );
    final value = await initialized();
    expect(value.formats.map((format) => format.id), contains(_id));
    expect(value.current.id, 'qpc_v1_builtin');
    expect(() => value.install(_id), throwsStateError);
  });
}

Map<String, dynamic> _catalog({
  required String sha256,
  String? licenseSha256,
  String? fontMode,
  bool wordAlignment = true,
  Map<String, dynamic>? extra,
}) => <String, dynamic>{
  'schema_version': 1,
  'formats': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': _id,
      'name': 'Digital Khatt v2',
      'description': 'Unicode fixture',
      'page_count': 604,
      'line_count': 15,
      'has_tajweed': false,
      'package_url': _packagePath,
      'sha256': sha256,
      'size_bytes': 0,
      'pagination_matches_builtin': true,
      'word_alignment_matches_builtin': wordAlignment,
      'font_mode': fontMode ?? 'unicode_single',
      if (licenseSha256 != null) 'license_sha256': licenseSha256,
      ...?extra,
    },
  ],
};

Uint8List _zip({
  required String? license,
  String? manifestMode,
  ArchiveFile? extra,
}) {
  final archive = Archive();
  final manifest = <String, dynamic>{
    'schema_version': 1,
    'id': _id,
    'page_count': 604,
    'line_count': 15,
    'pagination_matches_builtin': true,
    'word_alignment_matches_builtin': true,
    'font_mode': manifestMode ?? 'unicode_single',
    'license_sha256': sha256
        .convert(utf8.encode('Digital Khatt fixture license'))
        .toString(),
  };
  _add(archive, 'manifest.json', utf8.encode(jsonEncode(manifest)));
  _add(archive, 'words.sqlite', _sqlite);
  _add(archive, 'layout.sqlite', _sqlite);
  _add(archive, 'fonts/quran.otf', <int>[79, 84, 84, 79, 0, 1, 2, 3]);
  if (license != null) _add(archive, 'LICENSE.txt', utf8.encode(license));
  if (extra != null) archive.addFile(extra);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void _add(Archive archive, String name, List<int> bytes) =>
    archive.addFile(ArchiveFile(name, bytes.length, bytes));

Future<void> _writePackage(Directory resources, Uint8List bytes) async {
  final file = File('${resources.path}/$_packagePath');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _writeCatalog(
  Directory resources,
  Map<String, dynamic> catalog,
) async {
  final file = File('${resources.path}/mushaf/catalog.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(catalog), flush: true);
}
