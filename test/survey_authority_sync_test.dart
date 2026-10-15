import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/services/hijri_source_service.dart';
import 'package:hijri/hijri_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await AppLogger.init();
  });

  test('Survey Authority HTML Regex parses Cairo Hijri date correctly', () {
    const sampleHtml = '''
    <table class="table">
      <tr><th>المدينة</th><th>التاريخ الميلادي</th><th>التاريخ الهجري</th></tr>
      <tr><td>القاهرة</td><td>2026-09-21</td><td>9 ربيـــــــع الثانى 1448</td></tr>
      <tr><td>الأسكندرية</td><td>2026-09-21</td><td>9 ربيـــــــع الثانى 1448</td></tr>
    </table>
    ''';

    final regex = RegExp(
      r'القاهرة.*?<\/td>\s*<td[^>]*>[^<]*<\/td>\s*<td[^>]*>([^<]+)<\/td>',
      dotAll: true,
    );
    final match = regex.firstMatch(sampleHtml);
    expect(match, isNotNull);

    final hijriRaw = match!.group(1)?.replaceAll('ـ', '').trim() ?? '';
    expect(hijriRaw, equals('9 ربيع الثانى 1448'));

    final dayMatch = RegExp(r'(\d+)').firstMatch(hijriRaw);
    expect(dayMatch, isNotNull);
    final day = int.tryParse(dayMatch!.group(1)!);
    expect(day, equals(9));

    final parsed = HijriSourceDate.parse(hijriRaw);
    expect(parsed?.day, equals(9));
    expect(parsed?.month, equals(4));
    expect(parsed?.year, equals(1448));
  });

  test('Parses Dar Al-Ifta English month names and Arabic numerals', () {
    final darAlIftaDate = HijriSourceDate.parse("1 Rabi' Al-Akhir 1448");
    final arabicDigitsDate = HijriSourceDate.parse('١ جمادى الأولى ١٤٤٨');
    final shabanDate = HijriSourceDate.parse("5 Sha'ban 1448");
    final shawwalDate = HijriSourceDate.parse('1 Shawwal 1448');

    expect(darAlIftaDate?.day, equals(1));
    expect(darAlIftaDate?.month, equals(4));
    expect(darAlIftaDate?.year, equals(1448));
    expect(arabicDigitsDate?.day, equals(1));
    expect(arabicDigitsDate?.month, equals(5));
    expect(arabicDigitsDate?.year, equals(1448));
    expect(shabanDate?.month, equals(8));
    expect(shawwalDate?.month, equals(10));
  });

  test('Resolves an official first-of-month date from a local day 30', () {
    DateTime? localDay30;
    for (var i = 0; i < 370; i++) {
      final candidate = DateTime(2026, 1, 1).add(Duration(days: i));
      if (HijriCalendar.fromDate(candidate).hDay == 30) {
        localDay30 = candidate;
        break;
      }
    }
    expect(localDay30, isNotNull);

    final authorityTomorrow = HijriCalendar.fromDate(
      localDay30!.add(const Duration(days: 1)),
    );
    final authorityDate = HijriSourceDate(
      day: authorityTomorrow.hDay,
      month: authorityTomorrow.hMonth,
      year: authorityTomorrow.hYear,
    );

    expect(authorityDate.day, equals(1));
    expect(
      HijriSourceService.resolveOffsetForDate(authorityDate, localDay30),
      equals(1),
    );
  });
}
