import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

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
  static const _browserHeaders = <String, String>{
    'Cache-Control': 'no-cache',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
  };
  static bool _zonesReady = false;
  static const darIftaApiUrl =
      'http://di107.dar-alifta.org/api/HijriDate?langID=1';
  static const darIftaHttpsApiUrl =
      'https://di107.dar-alifta.org/api/HijriDate?langID=1';
  static const darIftaUrl =
      'https://www.dar-alifta.org/ar/services/details/12/التاريخ-الهجري';
  static const surveyUrl = 'https://www.esa.gov.eg/monthlymwaket.aspx';

  Future<http.Response> _get(String url, {required String source}) =>
      _request(
        () => client.get(Uri.parse(url), headers: _browserHeaders),
        source: source,
        method: 'GET',
      );

  Future<http.Response> _post(
    String url,
    Map<String, String> fields, {
    required String source,
    Map<String, String>? extraHeaders,
  }) => _request(
    () => client.post(
      Uri.parse(url),
      headers: {
        ..._browserHeaders,
        if (extraHeaders != null) ...extraHeaders,
        'Origin': Uri.parse(url).origin,
        'Referer': url,
      },
      body: fields,
    ),
    source: source,
    method: 'POST',
  );

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    required String source,
    required String method,
  }) async {
    final startedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    AppLogger.logEvent('EgyptianHijriSources', 'network_attempt_started', {
      'source': source,
      'method': method,
      'startedAt': startedAt.toIso8601String(),
      'timeoutSeconds': 15,
    });
    try {
      final response = await send().timeout(const Duration(seconds: 15));
      AppLogger.logEvent('EgyptianHijriSources', 'network_attempt_finished', {
        'source': source,
        'method': method,
        'httpStatus': response.statusCode,
        'outcome': response.statusCode >= 200 && response.statusCode < 300
            ? 'http_success'
            : 'http_failure',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      return response;
    } catch (error) {
      AppLogger.logEvent('EgyptianHijriSources', 'network_attempt_failed', {
        'source': source,
        'method': method,
        'reason': 'exception_${error.runtimeType}',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }
  static void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Official source HTTP ${response.statusCode}');
    }
  }

  static String _body(http.Response response) {
    final bytes = response.bodyBytes;
    final contentType = response.headers['content-type'] ?? '';
    final charset = RegExp(r'charset\s*=\s*([^;]+)', caseSensitive: false)
        .firstMatch(contentType)
        ?.group(1)
        ?.trim()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .toLowerCase();
    final hasLittleEndianBom =
        bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe;
    final hasBigEndianBom =
        bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff;
    final isUtf16 =
        hasLittleEndianBom ||
        hasBigEndianBom ||
        charset == 'utf-16' ||
        charset == 'utf-16le' ||
        charset == 'utf-16be';
    if (isUtf16) {
      final offset = hasLittleEndianBom || hasBigEndianBom ? 2 : 0;
      if ((bytes.length - offset).isOdd) {
        throw const FormatException('Invalid UTF-16 response body');
      }
      final littleEndian =
          hasLittleEndianBom || (!hasBigEndianBom && charset == 'utf-16le');
      final codeUnits = <int>[];
      for (var i = offset; i < bytes.length; i += 2) {
        codeUnits.add(
          littleEndian
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1],
        );
      }
      return String.fromCharCodes(codeUnits);
    }
    try {
      return utf8.decode(bytes);
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
    'المحرم': 1,
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
    'جماد الآخر': 6,
    'جماد الاخر': 6,
    'جماد الثاني': 6,
    'جماد الثانى': 6,
    'رجب': 7,
    'شعبان': 8,
    'رمضان': 9,
    'شوال': 10,
    'ذو القعدة': 11,
    'ذو القعده': 11,
    'ذوالقعدة': 11,
    'ذوالقعده': 11,
    'ذو الحجة': 12,
    'ذو الحجه': 12,
    'ذوالحجة': 12,
    'ذوالحجه': 12,
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

  static DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^[A-Za-z]{3},\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    const months = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final month = months[match.group(2)];
    if (month == null) return null;
    final day = int.parse(match.group(1)!);
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final result = DateTime.utc(year, month, day, hour, minute, second);
    if (result.year != year ||
        result.month != month ||
        result.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    return result;
  }

  static bool _sameCairoDay(DateTime instant, DateTime requested) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    final cairo = tz.TZDateTime.from(
      instant.toUtc(),
      tz.getLocation('Africa/Cairo'),
    );
    return _same(DateTime(cairo.year, cairo.month, cairo.day), requested);
  }

  /// Accept only the published current-date API's JSON string and only when
  /// its HTTP Date header belongs to the requested civil day in Cairo.
  static OfficialHijriValue? parseDarIftaApi(
    String body, {
    DateTime? civilDate,
    String? responseDate,
  }) {
    if (civilDate == null) {
      return null;
    }
    final servedAt = _parseHttpDate(responseDate);
    if (servedAt == null || !_sameCairoDay(servedAt, civilDate)) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! String) return null;
      final text = _clean(decoded);
      final match = RegExp(r'^(\d{1,2})\s+(.+?)\s+(\d{3,4})$')
          .firstMatch(text);
      if (match == null) return null;
      final day = int.parse(match.group(1)!);
      final month = _hijriMonths[match.group(2)!];
      final year = int.parse(match.group(3)!);
      if (month == null || day < 1 || day > 30 || year < 1 || year > 9999) {
        return null;
      }
      return OfficialHijriValue(day, month, year);
    } catch (_) {
      return null;
    }
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
        final r = await _get(endpoint, source: 'dar_alifta_current_date_api');
        _check(r);
        final value = parseDarIftaApi(
          _body(r),
          civilDate: cairoToday,
          responseDate: r.headers['date'],
        );
        if (value != null) {
          return DarIftaSnapshot(
            civilDate: cairoToday,
            hijri: value,
            sourceUrl: endpoint,
          );
        }
        AppLogger.logEvent(
          'EgyptianHijriSources',
          'source_value_rejected',
          {
            'source': 'dar_alifta_current_date_api',
            'civilDate': [
              cairoToday.year.toString().padLeft(4, '0'),
              cairoToday.month.toString().padLeft(2, '0'),
              cairoToday.day.toString().padLeft(2, '0'),
            ].join('-'),
            'reason': 'invalid_payload_or_http_date_not_current_cairo_day',
          },
        );
      } catch (_) {
        /* Fallback to the published current-date service page. */
      }
    }
    final response = await _get(
      darIftaUrl,
      source: 'dar_alifta_current_date_page',
    );
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
    final initial = await _get(
      surveyUrl,
      source: 'survey_authority_month_form',
    );
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
    final response = await _post(
      surveyUrl,
      fields,
      source: 'survey_authority_month_table',
      extraHeaders: headers,
    );
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
