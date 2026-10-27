class MushafFormatDatabaseCache<T> {
  final Map<String, T> _databases = {};
  final Map<String, Future<T>> _opening = {};

  Future<T> getOrOpen(String formatId, Future<T> Function() open) {
    final cached = _databases[formatId];
    if (cached != null) return Future<T>.value(cached);

    final inFlight = _opening[formatId];
    if (inFlight != null) return inFlight;

    late final Future<T> opening;
    opening = Future<T>.sync(open)
        .then((database) {
          _databases[formatId] = database;
          return database;
        })
        .whenComplete(() {
          if (identical(_opening[formatId], opening)) {
            _opening.remove(formatId);
          }
        });
    _opening[formatId] = opening;
    return opening;
  }
}
