import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/qadaa/qadaa_input_sanitizer.dart';

void main() {
  test('normalizes negative counts and clamps progress', () {
    expect(QadaaInputSanitizer.nonNegativeCount(-4), 0);
    expect(QadaaInputSanitizer.progress(12, 10), 0.0);
    expect(QadaaInputSanitizer.progress(-1, 10), 1.0);
    expect(QadaaInputSanitizer.progress(0, 0), 1.0);
  });

  test('rejects malformed or out-of-range time and calendar values', () {
    expect(QadaaInputSanitizer.parseTime('25:00'), isNull);
    expect(QadaaInputSanitizer.parseTime('08:60'), isNull);
    expect(QadaaInputSanitizer.parseTime('08:05'), (hour: 8, minute: 5));
    expect(QadaaInputSanitizer.month(0), 7);
    expect(QadaaInputSanitizer.month(13), 7);
    expect(QadaaInputSanitizer.month(9), 9);
    expect(QadaaInputSanitizer.weekDay(0), 7);
    expect(QadaaInputSanitizer.weekDay(8), 7);
    expect(QadaaInputSanitizer.weekDay(1), 1);
  });
}
