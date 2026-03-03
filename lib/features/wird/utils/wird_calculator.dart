import 'package:quran/quran.dart' as quran;

enum WirdUnit { page, juz }

class WirdSession {
  final int startPage;
  final int endPage;
  final bool isPartial;
  final int startSuraNumber;
  final int startAyah;
  final int endSuraNumber;
  final int endAyah;

  WirdSession({
    required this.startPage,
    required this.endPage,
    this.isPartial = false,
    required this.startSuraNumber,
    required this.startAyah,
    required this.endSuraNumber,
    required this.endAyah,
  });
}

class WirdCalculator {
  /// Juz start pages (Madinah mushaf, 1-indexed)
  static const List<int> juzStartPages = [
    1,
    22,
    42,
    62,
    82,
    102,
    121,
    142,
    162,
    182,
    202,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];

  /// Returns a WirdSession with precise boundaries.
  static WirdSession getSession({
    required int sessionIndex,
    required int totalSessions,
    WirdUnit unit = WirdUnit.page,
    int startFromPage = 1,
  }) {
    int totalPages;
    if (unit == WirdUnit.juz) {
      int startJuzIndex = 0;
      for (int i = juzStartPages.length - 1; i >= 0; i--) {
        if (startFromPage >= juzStartPages[i]) {
          startJuzIndex = i;
          break;
        }
      }
      int totalUnits = 30 - startJuzIndex;

      if (sessionIndex >= totalSessions) {
        sessionIndex = totalSessions - 1;
      }

      int baseUnits = totalUnits ~/ totalSessions;
      int extraUnits = totalUnits % totalSessions;

      List<int> sessionSizes = List.filled(totalSessions, baseUnits);

      if (extraUnits > 0) {
        int remainingExtras = extraUnits;
        if (startJuzIndex == 0 && remainingExtras > 0) {
          sessionSizes[0]++;
          remainingExtras--;
        }
        for (int i = 0; i < remainingExtras; i++) {
          int targetIndex = totalSessions - 1 - i;
          if (targetIndex >= 0 && targetIndex < totalSessions) {
            sessionSizes[targetIndex]++;
          }
        }
      }

      int startUnit = startJuzIndex;
      for (int i = 0; i < sessionIndex; i++) {
        startUnit += sessionSizes[i];
      }
      int endUnit = startUnit + sessionSizes[sessionIndex] - 1;

      if (startUnit >= 30) startUnit = 29;
      if (endUnit >= 30) endUnit = 29;

      int sPage = juzStartPages[startUnit];
      int ePage = (endUnit + 1 < 30) ? (juzStartPages[endUnit + 1] - 1) : 604;

      // 🟢 التعديل الجوهري: استخراج السورة والآية من الصفحة الفعلية 🟢
      // ده هيخلي الكلام المكتوب متطابق 100% مع الصفحة المعروضة
      int startSura = quran.getPageData(sPage).first['surah'] as int;
      int startAyah = quran.getPageData(sPage).first['start'] as int;

      int endSura = quran.getPageData(ePage).last['surah'] as int;
      int endAyah = quran.getPageData(ePage).last['end'] as int;

      return WirdSession(
        startPage: sPage,
        endPage: ePage,
        isPartial: true,
        startSuraNumber: startSura,
        startAyah: startAyah,
        endSuraNumber: endSura,
        endAyah: endAyah,
      );
    }

    // Page-based distribution
    totalPages = 604 - startFromPage + 1;
    if (totalPages <= 0) totalPages = 1;

    if (sessionIndex >= totalSessions) {
      sessionIndex = totalSessions - 1;
    }

    int baseUnits = totalPages ~/ totalSessions;
    int extraUnits = totalPages % totalSessions;

    List<int> sessionSizes = List.filled(totalSessions, baseUnits);

    if (extraUnits > 0) {
      int remainingExtras = extraUnits;
      if (startFromPage == 1 && remainingExtras > 0) {
        sessionSizes[0]++;
        remainingExtras--;
      }
      for (int i = 0; i < remainingExtras; i++) {
        int targetIndex = totalSessions - 1 - i;
        if (targetIndex >= 0 && targetIndex < totalSessions) {
          sessionSizes[targetIndex]++;
        }
      }
    }

    int startUnit = startFromPage;
    for (int i = 0; i < sessionIndex; i++) {
      startUnit += sessionSizes[i];
    }
    int endUnit = startUnit + sessionSizes[sessionIndex] - 1;

    if (endUnit < startUnit) endUnit = startUnit;
    if (startUnit > 604) startUnit = 604;
    if (endUnit > 604) endUnit = 604;

    int startSura = quran.getPageData(startUnit).first['surah'] as int;
    int startAyahVal = quran.getPageData(startUnit).first['start'] as int;
    int endSura = quran.getPageData(endUnit).last['surah'] as int;
    int endAyahVal = quran.getPageData(endUnit).last['end'] as int;

    return WirdSession(
      startPage: startUnit,
      endPage: endUnit,
      isPartial: false,
      startSuraNumber: startSura,
      startAyah: startAyahVal,
      endSuraNumber: endSura,
      endAyah: endAyahVal,
    );
  }

  static int getRemainingPages(int startJuz) {
    if (startJuz <= 1) return 604;
    if (startJuz > 30) return 0;
    return 604 - juzStartPages[startJuz - 1] + 1;
  }

  static int getPagesPerDay({
    required int amount,
    required WirdUnit unit,
    required bool isPerPrayer,
  }) {
    int pagesPerUnit;
    switch (unit) {
      case WirdUnit.page:
        pagesPerUnit = 1;
        break;
      case WirdUnit.juz:
        pagesPerUnit = 20;
        break;
    }
    int totalPerDay = amount * pagesPerUnit;
    if (isPerPrayer) {
      totalPerDay *= 5;
    }
    return totalPerDay;
  }
}
