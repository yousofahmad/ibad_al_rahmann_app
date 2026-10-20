import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';

String _json(Map<String, Map<String, int>> dates) => jsonEncode({
  'schemaVersion': 1,
  'source': {
    'name': EgyptianHijriCalendar.sourceName,
    'url': EgyptianHijriCalendar.sourceUrl,
    'city': EgyptianHijriCalendar.city,
  },
  'fetchedAt': '2026-01-01T00:00:00Z',
  'dates': dates,
});

class _CalendarBundle extends CachingAssetBundle {
  final String json;
  _CalendarBundle(this.json);

  @override
  Future<ByteData> load(String key) async {
    expect(key, EgyptianHijriCalendar.assetPath);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => EgyptianHijriCalendar.instance.resetForTesting());

  test(
    'loads the real bundled official year, with no fabricated future dates',
    () async {
      final service = EgyptianHijriCalendar.instance;
      await service.initialize();
      expect(service.isInitialized, isTrue);
      final raw = await rootBundle.loadString(EgyptianHijriCalendar.assetPath);
      final parsed = EgyptianHijriCalendar.parseJson(raw);
      expect(parsed.length, 365);
      expect(service.lookup(DateTime(2026, 1, 1))?.format, '12 رجب 1447 هـ');
      expect(
        service.lookup(DateTime(2026, 10, 18))?.format,
        '7 جمادى الأولى 1448 هـ',
      );
      expect(service.lookup(DateTime(2026, 12, 31)), isNotNull);
      expect(service.lookup(DateTime(2027, 1, 1)), isNull);
      expect(service.lookup(DateTime(2025, 12, 31)), isNull);
    },
  );

  test(
    'preserves published month boundaries, leap day and civil components',
    () async {
      final service = EgyptianHijriCalendar.instance;
      // Synthetic parser fixture, not a claim about historical Egyptian dates.
      await service.initialize(
        bundle: _CalendarBundle(
          _json({
            '2024-02-29': {'day': 29, 'month': 8, 'year': 1445},
            '2024-03-01': {'day': 30, 'month': 8, 'year': 1445},
            '2024-03-02': {'day': 1, 'month': 9, 'year': 1445},
          }),
        ),
      );
      expect(service.lookup(DateTime(2024, 2, 29))?.format, '29 شعبان 1445 هـ');
      expect(service.lookup(DateTime(2024, 3, 1))?.hDay, 30);
      expect(service.lookup(DateTime(2024, 3, 2))?.longMonthName, 'رمضان');
      // Time-of-day and UTC flags do not advance civil dates or apply offsets.
      expect(service.lookup(DateTime(2024, 3, 1, 23, 59))?.hDay, 30);
      expect(service.lookup(DateTime.utc(2024, 3, 1, 23, 59))?.hDay, 30);
      expect(service.lookup(DateTime(2024, 3, 3)), isNull);
    },
  );

  test('rejects malformed schema, source, timestamp and date components', () {
    expect(() => EgyptianHijriCalendar.parseJson('{}'), throwsFormatException);
    expect(
      () => EgyptianHijriCalendar.parseJson(
        _json({
          '2026-02-30': {'day': 1, 'month': 8, 'year': 1447},
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => EgyptianHijriCalendar.parseJson(
        _json({
          '2026-01-01': {'day': 31, 'month': 7, 'year': 1447},
        }),
      ),
      throwsFormatException,
    );
    for (final field in ['source', 'fetchedAt']) {
      final invalid = jsonDecode(_json({})) as Map<String, dynamic>;
      invalid[field] = 'invalid';
      expect(
        () => EgyptianHijriCalendar.parseJson(jsonEncode(invalid)),
        throwsFormatException,
      );
    }
  });
}
