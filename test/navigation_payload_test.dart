import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/navigation_payload.dart';

void main() {
  test('preserves underscores in khatma id while parsing from the right', () {
    final parsed = KhatmaNavigationPayload.parse('khatma_group_2026_3_10_20');

    expect(parsed, isNotNull);
    expect(parsed!.khatmaId, 'group_2026');
    expect(parsed.wirdIndex, 3);
    expect(parsed.targetStartPage, 10);
    expect(parsed.targetEndPage, 20);
  });

  test('rejects malformed and out-of-range structured payloads', () {
    expect(KhatmaNavigationPayload.parse('khatma_id_not-a-number_1_2'), isNull);
    expect(KhatmaNavigationPayload.parse('khatma_id_1_0_2'), isNull);
    expect(KhatmaNavigationPayload.parse('khatma_id_1_2_605'), isNull);
    expect(KhatmaNavigationPayload.parse('khatma_id_999999999_1_2'), isNull);
  });

  test('rejects an oversized payload before navigation', () {
    final payload = 'khatma_${'x' * 300}_1_2_3';
    expect(KhatmaNavigationPayload.parse(payload), isNull);
  });
}
