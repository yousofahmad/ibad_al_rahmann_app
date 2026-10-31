enum QuranVideoEncoderAttemptDisposition { succeeded, cancelled, retry }

class QuranVideoEncoderPolicy {
  const QuranVideoEncoderPolicy._();

  static QuranVideoEncoderAttemptDisposition decide({
    required bool timedOut,
    required bool succeeded,
    required bool cancelled,
  }) {
    if (!timedOut && succeeded) {
      return QuranVideoEncoderAttemptDisposition.succeeded;
    }
    if (!timedOut && cancelled) {
      return QuranVideoEncoderAttemptDisposition.cancelled;
    }
    return QuranVideoEncoderAttemptDisposition.retry;
  }
}
