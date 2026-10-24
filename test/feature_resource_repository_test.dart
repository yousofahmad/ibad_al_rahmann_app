import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';

void main() {
  late Directory root;
  late Directory outside;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('feature_resources_');
    outside = await Directory.systemTemp.createTemp('feature_resources_out_');
    await Directory('${root.path}/qul_local').create(recursive: true);
    await File('${root.path}/qul_local/data.bin').writeAsBytes(<int>[1, 2, 3]);
    await File('${outside.path}/secret.bin').writeAsBytes(<int>[9]);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await outside.exists()) await outside.delete(recursive: true);
  });

  test('reads bytes and JSON only from the configured tree', () async {
    await File(
      '${root.path}/qul_local/config.json',
    ).writeAsString('{"ok":true}');
    final repository = FeatureResourceRepository(rootPath: root.path);

    expect(await repository.readBytes('qul_local/data.bin'), <int>[1, 2, 3]);
    expect(await repository.readJson('qul_local/config.json'), {'ok': true});
    expect(await repository.fileUri('qul_local/data.bin'), startsWith('file:'));
    expect(await repository.readBytes('missing.bin'), isNull);
  });

  test('rejects unsafe relative paths', () async {
    final repository = FeatureResourceRepository(rootPath: root.path);
    for (final path in <String>[
      '../secret.bin',
      'qul_local/../secret.bin',
      '/etc/passwd',
      r'qul_local\data.bin',
      'file:///etc/passwd',
      'qul_local/%2e%2e/secret.bin',
      'qul_local//data.bin',
    ]) {
      expect(await repository.readBytes(path), isNull, reason: path);
    }
  });

  test('rejects symlink escapes', () async {
    final link = Link('${root.path}/qul_local/escape.bin');
    try {
      await link.create('${outside.path}/secret.bin');
    } on FileSystemException {
      return;
    }
    final repository = FeatureResourceRepository(rootPath: root.path);
    expect(await repository.readBytes('qul_local/escape.bin'), isNull);
    expect(await repository.containsFileUri(Uri.file(link.path)), isFalse);
  });

  test('accepts only canonical existing file URIs inside the root', () async {
    final repository = FeatureResourceRepository(rootPath: root.path);
    final inside = await repository.fileUri('qul_local/data.bin');
    expect(await repository.containsFileUri(Uri.parse(inside!)), isTrue);
    for (final uri in <Uri>[
      Uri.file('${outside.path}/secret.bin'),
      Uri.file('${root.path}/missing.bin'),
      Uri.parse('https://example.com/audio.mp3'),
      Uri.parse('file://remote-host${root.path}/qul_local/data.bin'),
      Uri.parse('$inside?token=not-allowed'),
      Uri.parse('$inside#fragment'),
    ]) {
      expect(await repository.containsFileUri(uri), isFalse);
    }
  });

  test('disabled empty root is inert', () async {
    final repository = FeatureResourceRepository(rootPath: '');
    expect(repository.enabled, isFalse);
    expect(await repository.readBytes('qul_local/data.bin'), isNull);
    expect(await repository.readJson('qul_local/config.json'), isNull);
    expect(await repository.fileUri('qul_local/data.bin'), isNull);
    expect(
      await repository.containsFileUri(
        Uri.file('${root.path}/qul_local/data.bin'),
      ),
      isFalse,
    );
  });

  test('does not expose mutable byte implementation details', () async {
    final repository = FeatureResourceRepository(rootPath: root.path);
    final bytes = await repository.readBytes('qul_local/data.bin');
    expect(bytes, isA<Uint8List>());
  });
}
