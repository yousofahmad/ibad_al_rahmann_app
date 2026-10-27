import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran/data/mushaf_format_database_cache.dart';

void main() {
  group('MushafFormatDatabaseCache', () {
    test(
      'coalesces concurrent opens and retains the opened database',
      () async {
        final cache = MushafFormatDatabaseCache<int>();
        final opened = Completer<int>();
        var openCount = 0;

        final first = cache.getOrOpen('qpc_v4_tajweed_1441', () {
          openCount++;
          return opened.future;
        });
        final second = cache.getOrOpen('qpc_v4_tajweed_1441', () {
          openCount++;
          return Future<int>.value(2);
        });

        expect(openCount, 1);
        opened.complete(1);
        expect(await first, 1);
        expect(await second, 1);
        expect(
          await cache.getOrOpen(
            'qpc_v4_tajweed_1441',
            () async => throw StateError('cached database should be reused'),
          ),
          1,
        );
        expect(openCount, 1);
      },
    );

    test('allows a new open after an earlier open fails', () async {
      final cache = MushafFormatDatabaseCache<int>();

      await expectLater(
        cache.getOrOpen('qpc_v2_1421', () async {
          throw StateError('temporary attach failure');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await cache.getOrOpen('qpc_v2_1421', () async => 42), 42);
    });
  });
}
