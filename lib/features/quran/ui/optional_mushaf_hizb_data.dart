import '../../../core/helpers/mushaf_pagination.dart';
import 'quran_hizb_data.dart';
import 'quran_rub_boundaries.dart';

/// Canonical rub boundaries for optional pagination; never modifies V1 data.
abstract final class OptionalMushafHizbData {
  static int _resolvedRevision = -1;
  static Map<int, String> _resolvedLabels = const {};
  static List<int> _resolvedPages = const [];

  /// Resolve the actual first ayah of every rub, not a V1 page's first ayah.
  static Map<int, String> resolveRubLabels(
    int Function(int surah, int ayah) pageForAyah,
  ) {
    final labels = <int, List<String>>{};
    for (final boundary in quranRubBoundaries) {
      final page = pageForAyah(boundary.surah, boundary.ayah);
      final label = boundary.label.startsWith('حزب ')
          ? boundary.label.replaceFirst('حزب ', 'الحزب ')
          : boundary.label;
      labels.putIfAbsent(page, () => []).add(label);
    }
    return Map.unmodifiable({
      for (final entry in labels.entries) entry.key: entry.value.join(' • '),
    });
  }

  static void _resolveSelectedLabels() {
    if (_resolvedRevision == MushafPagination.revision) return;
    _resolvedLabels = resolveRubLabels(MushafPagination.pageForAyah);
    _resolvedPages = _resolvedLabels.keys.toList()..sort();
    _resolvedRevision = MushafPagination.revision;
  }

  static String labelForPage(int pageNumber) {
    if (MushafPagination.isBuiltin) {
      return QuranHizbData.labelForPage(pageNumber);
    }
    _resolveSelectedLabels();
    return _resolvedLabels[pageNumber] ?? '';
  }

  static String activeLabelForPage(int pageNumber) {
    if (MushafPagination.isBuiltin) {
      return QuranHizbData.activeLabelForPage(pageNumber);
    }
    _resolveSelectedLabels();
    for (final page in _resolvedPages.reversed) {
      if (page <= pageNumber) return _resolvedLabels[page]!;
    }
    return 'الحزب ١';
  }
}
