/// Pure parsing helpers for notification-driven navigation.
class KhatmaNavigationPayload {
  const KhatmaNavigationPayload({
    required this.khatmaId,
    required this.wirdIndex,
    required this.targetStartPage,
    required this.targetEndPage,
  });

  final String khatmaId;
  final int wirdIndex;
  final int targetStartPage;
  final int targetEndPage;

  static const int maxPayloadLength = 256;
  static const int maxWirdIndex = 100000;
  static const int maxPage = 604;

  /// Parses `khatma_{id}_{wirdIndex}_{startPage}_{endPage}`.
  /// Returns null for malformed or out-of-range structured payloads.
  static KhatmaNavigationPayload? parse(String payload) {
    if (!payload.startsWith('khatma_') || payload.length > maxPayloadLength) {
      return null;
    }

    final parts = payload.substring('khatma_'.length).split('_');
    if (parts.length < 4) return null;

    final khatmaId = parts.sublist(0, parts.length - 3).join('_');
    final wirdIndex = int.tryParse(parts[parts.length - 3]);
    final startPage = int.tryParse(parts[parts.length - 2]);
    final endPage = int.tryParse(parts.last);

    if (khatmaId.isEmpty ||
        wirdIndex == null ||
        startPage == null ||
        endPage == null) {
      return null;
    }
    if (wirdIndex < 0 ||
        wirdIndex > maxWirdIndex ||
        startPage < 1 ||
        startPage > maxPage ||
        endPage < 1 ||
        endPage > maxPage ||
        startPage > endPage) {
      return null;
    }

    return KhatmaNavigationPayload(
      khatmaId: khatmaId,
      wirdIndex: wirdIndex,
      targetStartPage: startPage,
      targetEndPage: endPage,
    );
  }
}
