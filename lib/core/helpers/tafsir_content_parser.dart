import 'package:quran/quran.dart' as quran;

/// Parses the compact QUL tafsir archive format without I/O or Flutter state.
///
/// [parse] returns only ordinary Dart collections so its result can be sent
/// through a Flutter compute isolate. [parseWithStats] adds scalar diagnostics.
class TafsirContentParser {
  TafsirContentParser._();

  static final RegExp _keyPattern = RegExp(r'^([1-9][0-9]*):([1-9][0-9]*)$');

  /// Returns `surah -> [{"ayah": int, "text": String}, ...]`.
  static Map<int, List<Map<String, dynamic>>> parse(dynamic root) {
    return parseWithStats(root)['data'] as Map<int, List<Map<String, dynamic>>>;
  }

  /// Returns ordinary data under `data` and integer diagnostics under `stats`.
  static Map<String, dynamic> parseWithStats(dynamic root) {
    if (root is! Map || root.isEmpty) {
      throw const FormatException('Tafsir archive must be a non-empty object');
    }

    final entries = <String, dynamic>{};
    for (final entry in root.entries) {
      final key = entry.key.toString();
      if (_coordinate(key) != null) entries[key] = entry.value;
    }
    if (entries.isEmpty) {
      throw const FormatException('Tafsir archive has no valid ayah entries');
    }

    final memo = <String, _ResolvedEntry>{};
    var resolvedPointers = 0;
    var invalidReferences = 0;

    _ResolvedEntry resolve(String key) {
      final cached = memo[key];
      if (cached != null) return cached;

      final path = <String>[];
      final positions = <String, int>{};
      var pointerCount = 0;
      var current = key;
      _ResolvedEntry? answer;

      while (answer == null) {
        final known = memo[current];
        if (known != null) {
          answer = known;
          break;
        }
        final cycleAt = positions[current];
        if (cycleAt != null) {
          final cycle = path.sublist(cycleAt);
          const invalid = _ResolvedEntry.empty;
          for (final item in cycle) {
            memo[item] = invalid;
          }
          invalidReferences += cycle.length;
          answer = invalid;
          break;
        }

        positions[current] = path.length;
        path.add(current);
        final value = entries[current];
        if (value is String) {
          final trimmed = value.trim();
          final looksLikePointer = RegExp(r'^[0-9]+:[0-9]+$').hasMatch(trimmed);
          final pointer = _coordinate(trimmed);
          if (!looksLikePointer) {
            answer = _ResolvedEntry(value, <String>{current});
            break;
          }
          if (pointer == null || !entries.containsKey(trimmed)) {
            answer = _ResolvedEntry.empty;
            invalidReferences++;
            break;
          }
          pointerCount++;
          current = trimmed;
          continue;
        }
        answer = _entryValue(value, current);
        break;
      }

      for (final item in path.reversed) {
        memo[item] = answer;
      }
      resolvedPointers += pointerCount;
      return answer;
    }

    final bySurah = <int, Map<int, String>>{};
    for (final key in entries.keys) {
      final coordinate = _coordinate(key)!;
      final resolved = resolve(key);
      final targets = resolved.ayahKeys.isEmpty
          ? <String>[key]
          : {...resolved.ayahKeys, key}.toList();
      for (final target in targets) {
        // Explicit entries (including pointers) own their coordinate. Group
        // metadata may fill missing coordinates, never replace another entry.
        if (target != key && entries.containsKey(target)) continue;
        final targetCoordinate = _coordinate(target);
        if (targetCoordinate == null) continue;
        final surah = targetCoordinate.$1;
        final ayah = targetCoordinate.$2;
        final values = bySurah.putIfAbsent(surah, () => <int, String>{});
        final previous = values[ayah];
        if (previous == null ||
            (previous.isEmpty && resolved.text.isNotEmpty)) {
          values[ayah] = resolved.text;
        }
      }
      // A malformed object should still leave its valid archive key visible
      // as an empty entry, rather than silently turning it into a pointer.
      bySurah
          .putIfAbsent(coordinate.$1, () => <int, String>{})
          .putIfAbsent(coordinate.$2, () => resolved.text);
    }

    final data = <int, List<Map<String, dynamic>>>{};
    var nonEmptyAyahs = 0;
    for (final surah in bySurah.keys.toList()..sort()) {
      final ayahs = bySurah[surah]!.keys.toList()..sort();
      data[surah] = [
        for (final ayah in ayahs)
          <String, dynamic>{'ayah': ayah, 'text': bySurah[surah]![ayah]!},
      ];
      nonEmptyAyahs += ayahs
          .where((ayah) => bySurah[surah]![ayah]!.isNotEmpty)
          .length;
    }

    return <String, dynamic>{
      'data': data,
      'stats': <String, int>{
        'resolvedPointers': resolvedPointers,
        'invalidReferences': invalidReferences,
        'nonEmptyAyahs': nonEmptyAyahs,
        'surahCount': data.length,
      },
    };
  }

  static _ResolvedEntry _entryValue(dynamic value, String key) {
    if (value is String) return _ResolvedEntry(value, <String>{key});
    if (value is! Map) return _ResolvedEntry.empty;
    final rawText = value['text'];
    final text = rawText is String ? rawText : '';
    final keys = <String>{};
    final rawKeys = value['ayah_keys'];
    if (rawKeys is Iterable) {
      for (final item in rawKeys) {
        final candidate = item.toString();
        if (_coordinate(candidate) != null) keys.add(candidate);
      }
    }
    if (keys.isEmpty) keys.add(key);
    return _ResolvedEntry(text, keys);
  }

  static (int, int)? _coordinate(String value) {
    final match = _keyPattern.firstMatch(value);
    if (match == null) return null;
    final surah = int.tryParse(match.group(1)!);
    final ayah = int.tryParse(match.group(2)!);
    if (surah == null || ayah == null) return null;
    if (surah > quran.totalSurahCount) return null;
    try {
      if (ayah > quran.getVerseCount(surah)) return null;
    } catch (_) {
      return null;
    }
    return (surah, ayah);
  }
}

class _ResolvedEntry {
  const _ResolvedEntry(this.text, this.ayahKeys);
  static const empty = _ResolvedEntry('', <String>{});

  final String text;
  final Set<String> ayahKeys;
}

/// Isolate-friendly convenience API.
Map<int, List<Map<String, dynamic>>> parseTafsirContent(dynamic root) =>
    TafsirContentParser.parse(root);

/// Isolate-friendly API returning data and scalar parser diagnostics.
Map<String, dynamic> parseTafsirContentWithStats(dynamic root) =>
    TafsirContentParser.parseWithStats(root);
