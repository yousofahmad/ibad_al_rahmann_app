/// Serializes notification rebuilds and coalesces requests received mid-run.
/// Every caller waits until the latest requested settings have been applied.
class NotificationScheduleRunner {
  Future<void>? _active;
  bool _pending = false;
  bool _pendingUserAction = false;
  Future<void> Function(bool)? _latestRebuild;

  Future<void> run(
    Future<void> Function(bool isUserAction) rebuild, {
    required bool isUserAction,
  }) {
    _pending = true;
    _pendingUserAction = _pendingUserAction || isUserAction;
    _latestRebuild = rebuild;
    return _active ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending) {
        final userAction = _pendingUserAction;
        _pending = false;
        _pendingUserAction = false;
        final rebuild = _latestRebuild!;
        await Future<void>.sync(() => rebuild(userAction));
      }
    } finally {
      _active = null;
    }
  }
}
