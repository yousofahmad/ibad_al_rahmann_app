import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runLocalResourceTests = bool.fromEnvironment(
  'IBAD_RUN_LOCAL_RESOURCE_TESTS',
);
const _resourceRoot = String.fromEnvironment('IBAD_LOCAL_RESOURCE_ROOT');
const _manifestPath = 'qul_local/app_config.local.json';
const _auditPath =
    '/workspace/ibad_resource_audit/local_import/all_tafsir_parse_validation.json';

const _fakeAudioBytes = <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00];

class _FakeAudioAdapter implements HttpClientAdapter {
  var requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody(
      Stream<Uint8List>.fromIterable([Uint8List.fromList(_fakeAudioBytes)]),
      200,
      headers: {
        Headers.contentLengthHeader: ['${_fakeAudioBytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const skip = !_runLocalResourceTests;

  late FeatureResourceRepository repository;
  late Map<String, dynamic> manifest;
  late Directory documents;

  setUpAll(() async {
    repository = FeatureResourceRepository(rootPath: _resourceRoot);
    manifest =
        (await repository.readJson(_manifestPath)) ?? <String, dynamic>{};
    if (!skip) {
      SharedPreferences.setMockInitialValues({});
      await CacheHelper.init();
    }
  });

  setUp(() async {
    if (skip) return;
    documents = await Directory.systemTemp.createTemp('qul_local_integration_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documents.path;
          }
          return null;
        });
  });

  tearDown(() async {
    if (skip) return;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await documents.exists()) {
      await documents.delete(recursive: true);
    }
  });

  List<Map<String, dynamic>> manifestReciters() =>
      (manifest['audio_reciters'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<Map<String, dynamic>> manifestBooks() =>
      (manifest['tafseer_books'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  bool isOneAyahFolder(String folder) =>
      RegExp(r'^qul_ayah_[a-f0-9]{12}$').hasMatch(folder);

  test(
    'local catalog preserves built-in metadata and loads every local model',
    () async {
      final raw = manifestReciters();
      expect(raw, isNotEmpty);
      await ReciterAudioHelper.fetchRemoteReciters();
      final loaded = await ReciterAudioHelper.getReciters();
      final byId = <String, Map<String, dynamic>>{
        for (final item in loaded) item.id: item.toJson(),
      };
      for (final builtin in ReciterAudioHelper.defaultReciters) {
        final source = byId[builtin.id];
        expect(source, isNotNull, reason: 'missing built-in ${builtin.id}');
        final expected = builtin.toJson();
        for (final key in expected.keys) {
          expect(
            source![key],
            expected[key],
            reason: 'built-in metadata changed for ${builtin.id}: $key',
          );
        }
      }

      final loadedIds = loaded.map((item) => item.id).toSet();
      final importedIds = raw.map((item) => item['id'].toString());
      expect(loadedIds.length, raw.length);
      for (final id in importedIds) {
        expect(loadedIds, contains(id), reason: 'local model was dropped: $id');
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'local metadata preserves public audio URLs for full-surah and ayah-only resources',
    () async {
      await ReciterAudioHelper.fetchRemoteReciters();
      final builtinIds = ReciterAudioHelper.defaultReciters
          .map((model) => model.id)
          .toSet();
      final models = (await ReciterAudioHelper.getReciters())
          .where((model) => !builtinIds.contains(model.id))
          .toList();
      expect(models, isNotEmpty);
      final expectedSurahCounts = {
        for (final item in manifestReciters())
          if (item['surah_audio_url_count'] is num)
            item['id'].toString():
                (item['surah_audio_url_count'] as num).toInt(),
      };

      ReciterAudioModel? ayahOnly;
      for (final model in models) {
        if (isOneAyahFolder(model.folderName)) {
          ayahOnly ??= model;
          continue;
        }
        try {
          final surahs = await ReciterAudioHelper.getSurahs(model);
          final expectedCount = expectedSurahCounts[model.id];
          if (expectedCount != null) {
            expect(
              surahs,
              hasLength(expectedCount),
              reason: 'unexpected playable surah count for ${model.id}',
            );
          }
          for (final item in surahs.values) {
            expect(item.audioUrl, startsWith('https://'));
            expect(item.audioUrl, isNot(contains('file:')));
          }
          if (model.folderName !=
              'surah-recitation-sheikh-abu-bakr-dhaby-hafs-2020') {
            expect(
              surahs,
              isNotEmpty,
              reason: 'empty local source ${model.id}',
            );
          }
        } on StateError {
          expect(
            model.folderName,
            'surah-recitation-sheikh-abu-bakr-dhaby-hafs-2020',
            reason: 'unexpected local source failure for ${model.id}',
          );
        }
      }

      expect(ayahOnly, isNotNull);
      final segments = await ReciterAudioHelper.getSegments(ayahOnly!);
      expect(segments, isNotEmpty);
      for (final timing in segments.values) {
        if (timing.audioUrl != null) {
          expect(timing.audioUrl, startsWith('https://'));
          expect(timing.audioUrl, isNot(contains('file:')));
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'parses every imported QUL timing catalog with HTTPS audio links',
    () async {
      await ReciterAudioHelper.fetchRemoteReciters();
      final models = (await ReciterAudioHelper.getReciters())
          .where((model) => model.id.startsWith('qul_') && model.hasSegments)
          .toList();
      expect(models, isNotEmpty);

      for (final model in models) {
        final timings = await ReciterAudioHelper.getSegments(model);
        expect(timings, isNotEmpty, reason: 'missing timings for ${model.id}');
        for (final timing in timings.values) {
          if (timing.audioUrl != null) {
            expect(timing.audioUrl, startsWith('https://'));
            expect(timing.audioUrl, isNot(contains('file:')));
          }
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'downloads one public MP3 on demand into isolated documents with one callback',
    () async {
      final adapter = _FakeAudioAdapter();
      ReciterAudioHelper.dioFactory = () => Dio()..httpClientAdapter = adapter;
      addTearDown(() => ReciterAudioHelper.dioFactory = () => Dio());
      var completions = 0;
      bool? success;
      await ReciterAudioHelper.downloadSurah(
        'surah-recitation-abdul-basit-abd-us-samad-murattal',
        1,
        'https://cdn.example.test/001.mp3',
        onProgress: (_) {},
        onComplete: (value, _) {
          completions++;
          success = value;
        },
      );
      expect(adapter.requests, 1);
      expect(completions, 1);
      expect(success, isTrue);
      final downloaded = File(
        await ReciterAudioHelper.getOfflineSurahPath(
          'surah-recitation-abdul-basit-abd-us-samad-murattal',
          1,
        ),
      );
      expect(await downloaded.readAsBytes(), orderedEquals(_fakeAudioBytes));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'parses every available local tafsir archive and writes an audit summary',
    () async {
      final failures = <Map<String, dynamic>>[];
      var parsed = 0;
      for (final item in manifestBooks()) {
        if (item['local_only'] != true || item['is_builtin'] == true) continue;
        final id = item['id']?.toString() ?? '';
        final url = item['url']?.toString() ?? '';
        try {
          final relative = url.startsWith('qul_local/') ? url : '';
          final bytes = await repository.readBytes(relative);
          if (bytes == null) throw StateError('missing_archive:$relative');
          final prepared = prepareDownloadedArchive(bytes);
          final stats = Map<String, dynamic>.from(prepared['stats'] as Map);
          final readable = (stats['readableAyahs'] as num?)?.toInt() ?? 0;
          if (readable <= 0) throw StateError('readableAyahs_zero');
          parsed++;
        } catch (error) {
          failures.add(<String, dynamic>{
            'id': id,
            'name': item['name'],
            'url': url,
            'error': error.toString(),
          });
        }
      }

      final report = <String, dynamic>{
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'resource_root': _resourceRoot,
        'available_local_books': parsed + failures.length,
        'parsed': parsed,
        'failures': failures,
      };
      final output = File(_auditPath);
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      expect(failures, isEmpty, reason: 'see $_auditPath');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
