import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_encoder_policy.dart';

void main() {
  group('QuranVideoEncoderPolicy', () {
    test(
      'retries after a timeout even if the session has no final return code',
      () {
        expect(
          QuranVideoEncoderPolicy.decide(
            timedOut: true,
            succeeded: false,
            cancelled: false,
          ),
          QuranVideoEncoderAttemptDisposition.retry,
        );
      },
    );

    test('accepts a completed successful encoder attempt', () {
      expect(
        QuranVideoEncoderPolicy.decide(
          timedOut: false,
          succeeded: true,
          cancelled: false,
        ),
        QuranVideoEncoderAttemptDisposition.succeeded,
      );
    });

    test('does not retry an explicitly cancelled encoder attempt', () {
      expect(
        QuranVideoEncoderPolicy.decide(
          timedOut: false,
          succeeded: false,
          cancelled: true,
        ),
        QuranVideoEncoderAttemptDisposition.cancelled,
      );
    });
  });
}
