import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';

List<int> _zip(Map<String, dynamic> root) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('tafseer.json', json.encode(root)));
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tafsir_local_import_');
    await Directory('${root.path}/qul_local/tafseer').create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'local plain JSON and ZIP both use the production archive preparer',
    () async {
      final source = <String, dynamic>{
        '1:1': <String, dynamic>{'text': 'Local plain text'},
      };
      final plainPath = '${root.path}/qul_local/tafseer/plain.json';
      final zipPath = '${root.path}/qul_local/tafseer/archive.json.zip';
      await File(plainPath).writeAsString(json.encode(source));
      await File(zipPath).writeAsBytes(_zip(source));
      final repository = FeatureResourceRepository(rootPath: root.path);

      final plain = await repository.readBytes('qul_local/tafseer/plain.json');
      final zipped = await repository.readBytes(
        'qul_local/tafseer/archive.json.zip',
      );
      expect(plain, isNotNull);
      expect(zipped, isNotNull);

      final plainResult = prepareDownloadedArchive(plain!);
      final zipResult = prepareDownloadedArchive(zipped!);
      expect(
        json.decode(
          Map<String, String>.from(plainResult['files'] as Map)['1']!,
        )['ayahs'][0]['text'],
        'Local plain text',
      );
      expect(
        json.decode(
          Map<String, String>.from(zipResult['files'] as Map)['1']!,
        )['ayahs'][0]['text'],
        'Local plain text',
      );
      expect((plainResult['files'] as Map).length, 114);
      expect((zipResult['files'] as Map).length, 114);
    },
  );
}
