import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sources.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sync.dart';

// Explicit opt-in: official sites may be offline/stale; never make normal CI
// depend on them. No live response is written to the bundled calendar here.
void main() {
  const enabled = bool.fromEnvironment('EGYPTIAN_HIJRI_LIVE');
  test(
    'live Dar Ifta civil/Hijri pair and live ESA current month',
    () async {
      final sources = EgyptianHijriSources();
      try {
        final today = EgyptianHijriSync.cairoToday();
        final snapshot = await sources.fetchDarIfta(today);
        expect(snapshot.civilDate, today);
        final month = await sources.fetchSurveyMonth(today.month, today.year);
        final key =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        expect(month[key], isNotNull);
        // This is a diagnostic, not an assertion that both sources must agree.
        // ignore: avoid_print
        print(
          'LIVE $key Dar Ifta=${snapshot.hijri.toJson()} ESA=${month[key]} source=${snapshot.sourceUrl} monthRows=${month.length}',
        );
      } finally {
        sources.close();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
