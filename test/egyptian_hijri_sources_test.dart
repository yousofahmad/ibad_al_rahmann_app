import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sources.dart';

String _header(int day, {int hijri = 7}) =>
    '<div class="wrap"><div class="container"><div class="date">الإثنين, $day أكتوبر 2026 – \uFEFF$hijri جُمادى الأولى 1448 هـ</div></div></div>';
String _month(int month, int year, {bool badHijri = false}) {
  final rows = List.generate(
    DateTime(year, month + 1, 0).day,
    (i) =>
        '<tr><td>القاهرة</td><td>$year-${month.toString().padLeft(2, '0')}-${(i + 1).toString().padLeft(2, '0')}</td><td>${badHijri ? 31 : (i % 30) + 1} جماد الأول 1448</td><td>IGNORED</td></tr>',
  ).join();
  return '<table id="placeholder1_GridView1"><tr><th>مدينة</th></tr>$rows</table>';
}

http.Response _html(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

void main() {
  test(
    'unknown API JSON and bare dates never become a verified current date',
    () {
      for (final body in [
        '{"day":7,"month":5,"year":1448}',
        '{"date":"2026-10-19","data":{"day":7,"month":5,"year":1448}}',
        '7 جمادى الأولى 1448',
      ]) {
        expect(
          EgyptianHijriSources.parseDarIftaApi(
            body,
            civilDate: DateTime(2026, 10, 19),
          ),
          isNull,
        );
      }
    },
  );
  test('Dar API date string requires a current Cairo HTTP Date header', () {
    const body = '"14 جُمادى الأولى 1448"';
    expect(
      EgyptianHijriSources.parseDarIftaApi(
        body,
        civilDate: DateTime(2026, 10, 25),
        responseDate: 'Sun, 25 Oct 2026 10:25:55 GMT',
      ),
      const OfficialHijriValue(14, 5, 1448),
    );
    expect(
      EgyptianHijriSources.parseDarIftaApi(
        body,
        civilDate: DateTime(2026, 10, 25),
        responseDate: 'Sat, 24 Oct 2026 10:25:55 GMT',
      ),
      isNull,
    );
    expect(
      EgyptianHijriSources.parseDarIftaApi(
        '{"day":14,"month":5,"year":1448}',
        civilDate: DateTime(2026, 10, 25),
        responseDate: 'Sun, 25 Oct 2026 10:25:55 GMT',
      ),
      isNull,
    );
  });
  test('Dar API UTF-16LE JSON body is decoded before parsing', () async {
    const json = '"14 جُمادى الأولى 1448"';
    final bytes = <int>[0xff, 0xfe];
    for (final codeUnit in json.codeUnits) {
      bytes
        ..add(codeUnit & 0xff)
        ..add(codeUnit >> 8);
    }
    final source = EgyptianHijriSources(
      client: MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {
            'content-type': 'application/json; charset=utf-16',
            'date': 'Sun, 25 Oct 2026 10:25:55 GMT',
          },
        ),
      ),
    );

    final snapshot = await source.fetchDarIfta(DateTime(2026, 10, 25));

    expect(snapshot.hijri, const OfficialHijriValue(14, 5, 1448));
    source.close();
  });
  test('actual top date accepts only a paired current civil date', () {
    expect(
      EgyptianHijriSources.parseDarIftaHeader(
        _header(19),
        DateTime(2026, 10, 19),
      )?.$2,
      const OfficialHijriValue(7, 5, 1448),
    );
    expect(
      EgyptianHijriSources.parseDarIftaHeader(
        _header(16),
        DateTime(2026, 10, 19),
      ),
      isNull,
    );
    expect(
      EgyptianHijriSources.parseDarIftaHeader(
        '<article>19 أكتوبر 2026 – 7 جمادى الأولى 1448 هـ</article>',
        DateTime(2026, 10, 19),
      ),
      isNull,
    );
    expect(
      EgyptianHijriSources.parseDarIftaHeader(
        '${_header(16)}<article>19 أكتوبر 2026 – 7 جمادى الأولى 1448 هـ</article>',
        DateTime(2026, 10, 19),
      ),
      isNull,
    );
    expect(
      EgyptianHijriSources.parseDarIftaHeader(
        '${_header(19)}${_header(19)}',
        DateTime(2026, 10, 19),
      ),
      isNull,
    );
  });
  test(
    'ESA published جماد spelling and full civil month are parsed without prayer data',
    () {
      final result = EgyptianHijriSources.parseSurveyMonth(
        _month(1, 2026),
        month: 1,
        expectedYear: 2026,
      );
      expect(result.length, 31);
      expect(result['2026-01-19'], {'day': 19, 'month': 5, 'year': 1448});
      expect(result['2026-01-31']!['day'], 1);
      final rabi = EgyptianHijriSources.parseSurveyMonth(
        _month(10, 2026).replaceAll('جماد الأول', 'ربيع الثانى'),
        month: 10,
        expectedYear: 2026,
      );
      expect(rabi['2026-10-01']!['month'], 4);
    },
  );
  test('ESA live compact month spellings are parsed', () {
    const spellings = {
      'المحرم': 1,
      'جماد الآخر': 6,
      'ذوالقعدة': 11,
      'ذوالحجة': 12,
    };
    for (final entry in spellings.entries) {
      final result = EgyptianHijriSources.parseSurveyMonth(
        _month(1, 2026).replaceAll('جماد الأول', entry.key),
        month: 1,
        expectedYear: 2026,
      );
      expect(result['2026-01-01']!['month'], entry.value, reason: entry.key);
    }
  });
  test(
    'ESA parser rejects bad dates, wrong year, duplicate days and incomplete months',
    () {
      for (final body in [
        _month(1, 2025),
        _month(1, 2026, badHijri: true),
        _month(1, 2026).replaceFirst('2026-01-31', '2026-01-30'),
        _month(1, 2026).replaceFirst('2026-01-31', '2026-01-32'),
        '<table id="placeholder1_GridView1"><tr><th>مدينة</th></tr></table>',
      ]) {
        expect(
          () => EgyptianHijriSources.parseSurveyMonth(
            body,
            month: 1,
            expectedYear: 2026,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'API failure falls back to official HTTPS date element, rejects stale page',
    () async {
      var pageDay = 19;
      final seen = <String>[];
      final source = EgyptianHijriSources(
        client: MockClient((request) async {
          seen.add(request.url.toString());
          if (request.url.host == 'di107.dar-alifta.org') {
            throw http.ClientException('API unavailable');
          }
          expect(
            request.url.toString(),
            Uri.parse(EgyptianHijriSources.darIftaUrl).toString(),
          );
          return _html(_header(pageDay));
        }),
      );
      final snapshot = await source.fetchDarIfta(DateTime(2026, 10, 19));
      expect(snapshot.hijri, const OfficialHijriValue(7, 5, 1448));
      expect(snapshot.sourceUrl, EgyptianHijriSources.darIftaUrl);
      expect(seen.length, 3);
      pageDay = 16;
      await expectLater(
        source.fetchDarIfta(DateTime(2026, 10, 19)),
        throwsFormatException,
      );
      source.close();
    },
  );
  test(
    'ESA uses real ASP.NET GET state then form POST, preserving cookie and city option',
    () async {
      final source = EgyptianHijriSources(
        client: MockClient((request) async {
          expect(request.url.toString(), EgyptianHijriSources.surveyUrl);
          expect(request.headers['user-agent'], contains('Mozilla/5.0'));
          if (request.method == 'GET') {
            return http.Response(
              '<form id="ctl00"><input type="hidden" name="__VIEWSTATE" value="state123"><select id="placeholder1_DropDownList1"><option value="القـاهـرة">القـاهـرة</option></select></form>',
              200,
              headers: {
                'content-type': 'text/html; charset=utf-8',
                'set-cookie': 'ASP.NET_SessionId=abc; path=/; HttpOnly',
              },
            );
          }
          expect(request.headers['origin'], 'https://www.esa.gov.eg');
          final fields = Uri.splitQueryString(request.body);
          expect(fields['__VIEWSTATE'], 'state123');
          expect(fields['ctl00\$placeholder1\$DropDownList1'], 'القـاهـرة');
          expect(fields['ctl00\$placeholder1\$DropDownList2'], '1');
          expect(request.headers['Cookie'], 'ASP.NET_SessionId=abc');
          return _html(_month(1, 2026));
        }),
      );
      expect((await source.fetchSurveyMonth(1, 2026)).length, 31);
      source.close();
    },
  );
  test(
    'annual adapter requests all twelve months and validates returned actual year',
    () async {
      var posts = 0;
      final source = EgyptianHijriSources(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return _html(
              '<form id="ctl00"><select id="placeholder1_DropDownList1"><option value="القـاهـرة">القاهرة</option></select></form>',
            );
          }
          posts++;
          final month = int.parse(
            Uri.splitQueryString(
              request.body,
            )['ctl00\$placeholder1\$DropDownList2']!,
          );
          return _html(_month(month, 2026));
        }),
      );
      expect((await source.fetchSurveyYear(2026)).length, 365);
      expect(posts, 12);
      await expectLater(source.fetchSurveyYear(2027), throwsFormatException);
      source.close();
    },
  );
}
