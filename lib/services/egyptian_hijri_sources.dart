import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class OfficialHijriValue {
  final int day, month, year;
  const OfficialHijriValue(this.day, this.month, this.year);
  Map<String, int> toJson() => {'day': day, 'month': month, 'year': year};
  @override
  bool operator ==(Object other) =>
      other is OfficialHijriValue &&
      other.day == day &&
      other.month == month &&
      other.year == year;
  @override
  int get hashCode => Object.hash(day, month, year);
}

class DarIftaSnapshot {
  final DateTime civilDate;
  final OfficialHijriValue hijri;
  final String sourceUrl;
  const DarIftaSnapshot({
    required this.civilDate,
    required this.hijri,
    required this.sourceUrl,
  });
}

class EgyptianHijriSources {
  final http.Client client;
  EgyptianHijriSources({http.Client? client})
    : client = client ?? http.Client();
  static const darIftaApiUrl =
      'http://di107.dar-alifta.org/api/HijriDate?langID=1';
  static const darIftaHttpsApiUrl =
      'https://di107.dar-alifta.org/api/HijriDate?langID=1';
  static const darIftaUrl =
      'https://www.dar-alifta.org/ar/services/details/12/التاريخ-الهجري';
  static const surveyUrl = 'https://www.esa.gov.eg/monthlymwaket.aspx';

  Future<http.Response> _get(String url) => client
      .get(Uri.parse(url), headers: const {'Cache-Control': 'no-cache'})
      .timeout(const Duration(seconds: 15));
  static void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Official source HTTP ${response.statusCode}');
    }
  }

  static String _body(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  static String _clean(String text) {
    const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
    }
    return text
        .replaceAll(
          RegExp(r'[\u0640\u064B-\u065F\u0670\u200e\u200f\ufeff]'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final _hijriMonths = <String, int>{
    'محرم': 1,
    'صفر': 2,
    'ربيع الأول': 3,
    'ربيع الاول': 3,
    'ربيع الثاني': 4,
    'ربيع الثانى': 4,
    'ربيع الآخر': 4,
    'ربيع الاخر': 4,
    'جمادى الأولى': 5,
    'جمادى الاولى': 5,
    'جماد الأول': 5,
    'جماد الاول': 5,
    'جمادى الثانية': 6,
    'جمادى الآخرة': 6,
    'جمادى الاخرة': 6,
    'جماد الثاني': 6,
    'جماد الثانى': 6,
    'رجب': 7,
    'شعبان': 8,
    'رمضان': 9,
    'شوال': 10,
    'ذو القعدة': 11,
    'ذو القعده': 11,
    'ذو الحجة': 12,
    'ذو الحجه': 12,
  };
  static const _civilMonths = <String, int>{
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'أبريل': 4,
    'ابريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يوليو': 7,
    'أغسطس': 8,
    'اغسطس': 8,
    'سبتمبر': 9,
    'أكتوبر': 10,
    'اكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The unavailable API has no verified JSON contract. Do not invent one or
  /// date-stamp a bare Hijri string. Only the same proven HTML civil-date pair
  /// can be accepted; otherwise fetch the official current-date HTTPS page.
  static OfficialHijriValue? parseDarIftaApi(
    String body, {
    DateTime? civilDate,
  }) {
    if (civilDate == null ||
        body.trimLeft().startsWith('{') ||
        body.trimLeft().startsWith('[')) {
      return null;
    }
    return parseDarIftaHeader(body, civilDate)?.$2;
  }

  static (DateTime, OfficialHijriValue)? parseDarIftaHeader(
    String body,
    DateTime requested,
  ) {
    final doc = html_parser.parse(body);
    // Observed live DOM: body > div.wrap ... div.date. Do not scan articles.
    final candidates = doc.querySelectorAll('body > .wrap .date, header .date');
    if (candidates.length != 1) return null;
    final text = _clean(candidates.single.text);
    final pair = RegExp(
      r'^(?:[^\d]*)(\d{1,2})\s+(يناير|فبراير|مارس|أبريل|ابريل|مايو|يونيو|يوليو|أغسطس|اغسطس|سبتمبر|أكتوبر|اكتوبر|نوفمبر|ديسمبر)\s+(\d{4})\s*[–—-]\s*(\d{1,2})\s+(.+?)\s+(\d{4})\s*(?:هـ|ه)\s*$',
    ).firstMatch(text);
    if (pair == null) return null;
    final day = int.parse(pair.group(1)!),
        month = _civilMonths[pair.group(2)!]!,
        year = int.parse(pair.group(3)!);
    final civil = DateTime(year, month, day);
    if (civil.year != year ||
        civil.month != month ||
        civil.day != day ||
        !_same(civil, requested)) {
      return null;
    }
    final hm = _hijriMonths[pair.group(5)!],
        hd = int.parse(pair.group(4)!),
        hy = int.parse(pair.group(6)!);
    if (hm == null || hd < 1 || hd > 30 || hy < 1 || hy > 9999) return null;
    return (civil, OfficialHijriValue(hd, hm, hy));
  }

  Future<DarIftaSnapshot> fetchDarIfta(DateTime cairoToday) async {
    for (final endpoint in [darIftaHttpsApiUrl, darIftaApiUrl]) {
      try {
        final r = await _get(endpoint);
        _check(r);
        final value = parseDarIftaApi(_body(r), civilDate: cairoToday);
        if (value != null) {
          return DarIftaSnapshot(
            civilDate: cairoToday,
            hijri: value,
            sourceUrl: endpoint,
          );
        }
      } catch (_) {
        /* Fallback to the published current-date service page. */
      }
    }
    final response = await _get(darIftaUrl);
    _check(response);
    final pair = parseDarIftaHeader(_body(response), cairoToday);
    if (pair == null) {
      throw const FormatException(
        'Dar Ifta official date element is missing, stale or malformed',
      );
    }
    return DarIftaSnapshot(
      civilDate: pair.$1,
      hijri: pair.$2,
      sourceUrl: darIftaUrl,
    );
  }

  Future<Map<String, Map<String, int>>> fetchSurveyMonth(
    int month,
    int year,
  ) async {
    if (month < 1 || month > 12 || year < 1 || year > 9999) {
      throw ArgumentError('Invalid requested Gregorian year/month');
    }
    final initial = await _get(surveyUrl);
    _check(initial);
    final doc = html_parser.parse(_body(initial));
    final form = doc.querySelector('form#ctl00');
    if (form == null) throw const FormatException('ESA form missing');
    final fields = <String, String>{};
    for (final input in form.querySelectorAll('input[type="hidden"][name]')) {
      fields[input.attributes['name']!] = input.attributes['value'] ?? '';
    }
    final options = doc
        .querySelectorAll('#placeholder1_DropDownList1 option')
        .where((o) => _clean(o.text).replaceAll(' ', '') == 'القاهرة')
        .toList();
    if (options.length != 1 || options.single.attributes['value'] == null) {
      throw const FormatException('ESA Cairo option missing');
    }
    fields['ctl00\$placeholder1\$DropDownList1'] =
        options.single.attributes['value']!;
    fields['ctl00\$placeholder1\$DropDownList2'] = '$month';
    final headers = <String, String>{
      'Cache-Control': 'no-cache',
      'Referer': surveyUrl,
    };
    final cookies = initial.headers['set-cookie'];
    if (cookies != null) {
      headers['Cookie'] = cookies
          .split(RegExp(r',(?=\s*[^;,=\s]+=)'))
          .map((cookie) => cookie.split(';').first.trim())
          .join('; ');
    }
    final response = await client
        .post(Uri.parse(surveyUrl), headers: headers, body: fields)
        .timeout(const Duration(seconds: 15));
    _check(response);
    return parseSurveyMonth(_body(response), month: month, expectedYear: year);
  }

  static Map<String, Map<String, int>> parseSurveyMonth(
    String body, {
    required int month,
    required int expectedYear,
  }) {
    if (month < 1 || month > 12 || expectedYear < 1) {
      throw const FormatException('Invalid requested month');
    }
    final table = html_parser
        .parse(body)
        .querySelector('table#placeholder1_GridView1');
    if (table == null) {
      throw const FormatException('ESA monthly GridView missing');
    }
    final result = <String, Map<String, int>>{};
    final days = DateTime(expectedYear, month + 1, 0).day;
    for (final row in table.querySelectorAll('tr').skip(1)) {
      final cells = row
          .querySelectorAll('td')
          .map((cell) => _clean(cell.text))
          .toList();
      if (cells.length < 3 || cells[0].replaceAll(' ', '') != 'القاهرة') {
        continue;
      }
      final civil = RegExp(
        r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
      ).firstMatch(cells[1]);
      final hijri = RegExp(
        r'^(\d{1,2})\s+(.+?)\s+(\d{3,4})$',
      ).firstMatch(cells[2]);
      if (civil == null || hijri == null) {
        throw const FormatException('Invalid ESA date row');
      }
      final y = int.parse(civil.group(1)!),
          m = int.parse(civil.group(2)!),
          d = int.parse(civil.group(3)!);
      final hd = int.parse(hijri.group(1)!),
          hm = _hijriMonths[hijri.group(2)!],
          hy = int.parse(hijri.group(3)!);
      if (y != expectedYear ||
          m != month ||
          d < 1 ||
          d > days ||
          hd < 1 ||
          hd > 30 ||
          hm == null ||
          hy < 1 ||
          hy > 9999) {
        throw const FormatException('Invalid or wrong-year ESA date');
      }
      final key =
          '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (result.containsKey(key)) {
        throw const FormatException('Duplicate ESA civil day');
      }
      result[key] = {'day': hd, 'month': hm, 'year': hy};
    }
    if (result.length != days) {
      throw const FormatException('Incomplete ESA month');
    }
    return result;
  }

  Future<Map<String, Map<String, int>>> fetchSurveyYear(int year) async {
    final result = <String, Map<String, int>>{};
    for (var month = 1; month <= 12; month++) {
      result.addAll(await fetchSurveyMonth(month, year));
    }
    return result;
  }

  void close() => client.close();
}

typedef HttpEgyptianHijriSources = EgyptianHijriSources;
