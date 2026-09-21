import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

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
  });
}
