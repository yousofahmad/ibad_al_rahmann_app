import 'package:quran/quran.dart' as quran;

enum WirdUnit { page, juz, quarter }

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

  /// Actual Hizb Quarter (Rub' al-Hizb) boundaries — [surah, ayah]
  /// 240 quarters: 30 juz × 2 hizb × 4 quarters = 240
  /// Standard Madinah mushaf markers
  static const List<List<int>> _quarterMarkers = [
    // Juz 1 (Hizb 1-2)
    [1, 1], [2, 6], [2, 17], [2, 25], // Hizb 1
    [2, 30], [2, 38], [2, 49], [2, 58], // Hizb 2
    // Juz 2 (Hizb 3-4)
    [2, 142], [2, 146], [2, 153], [2, 164], // Hizb 3
    [2, 177], [2, 189], [2, 197], [2, 203], // Hizb 4
    // Juz 3 (Hizb 5-6)
    [2, 253], [2, 258], [2, 264], [2, 271], // Hizb 5
    [2, 283], [3, 10], [3, 16], [3, 23], // Hizb 6
    // Juz 4 (Hizb 7-8)
    [3, 93], [3, 101], [3, 110], [3, 121], // Hizb 7
    [3, 133], [3, 141], [3, 153], [3, 171], // Hizb 8
    // Juz 5 (Hizb 9-10)
    [4, 24], [4, 34], [4, 45], [4, 60], // Hizb 9
    [4, 75], [4, 88], [4, 100], [4, 114], // Hizb 10
    // Juz 6 (Hizb 11-12)
    [4, 148], [4, 163], [5, 1], [5, 12], // Hizb 11
    [5, 27], [5, 35], [5, 46], [5, 60], // Hizb 12
    // Juz 7 (Hizb 13-14)
    [5, 82], [5, 97], [5, 109], [6, 13], // Hizb 13
    [6, 36], [6, 59], [6, 74], [6, 95], // Hizb 14
    // Juz 8 (Hizb 15-16)
    [6, 111], [6, 127], [6, 141], [6, 151], // Hizb 15
    [7, 1], [7, 31], [7, 47], [7, 65], // Hizb 16
    // Juz 9 (Hizb 17-18)
    [7, 88], [7, 117], [7, 142], [7, 156], // Hizb 17
    [7, 171], [7, 189], [8, 1], [8, 22], // Hizb 18
    // Juz 10 (Hizb 19-20)
    [8, 41], [8, 61], [9, 1], [9, 19], // Hizb 19
    [9, 34], [9, 46], [9, 60], [9, 75], // Hizb 20
    // Juz 11 (Hizb 21-22)
    [9, 93], [9, 111], [9, 122], [10, 1], // Hizb 21
    [10, 26], [10, 53], [10, 71], [10, 90], // Hizb 22
    // Juz 12 (Hizb 23-24)
    [11, 6], [11, 24], [11, 41], [11, 61], // Hizb 23
    [11, 84], [11, 108], [12, 7], [12, 30], // Hizb 24
    // Juz 13 (Hizb 25-26)
    [12, 53], [12, 77], [12, 101], [13, 5], // Hizb 25
    [13, 19], [13, 35], [14, 10], [14, 28], // Hizb 26
    // Juz 14 (Hizb 27-28)
    [15, 1], [15, 50], [15, 80], [16, 1], // Hizb 27
    [16, 30], [16, 65], [16, 90], [16, 111], // Hizb 28
    // Juz 15 (Hizb 29-30)
    [17, 1], [17, 23], [17, 50], [17, 70], // Hizb 29
    [17, 99], [18, 17], [18, 32], [18, 51], // Hizb 30
    // Juz 16 (Hizb 31-32)
    [18, 75], [18, 99], [19, 22], [19, 59], // Hizb 31
    [19, 75], [20, 55], [20, 83], [20, 111], // Hizb 32
    // Juz 17 (Hizb 33-34)
    [21, 1], [21, 29], [21, 51], [21, 83], // Hizb 33
    [22, 1], [22, 19], [22, 38], [22, 60], // Hizb 34
    // Juz 18 (Hizb 35-36)
    [23, 1], [23, 36], [23, 75], [24, 1], // Hizb 35
    [24, 21], [24, 35], [24, 53], [24, 59], // Hizb 36
    // Juz 19 (Hizb 37-38)
    [25, 21], [25, 53], [26, 1], [26, 52], // Hizb 37
    [26, 111], [26, 181], [27, 1], [27, 27], // Hizb 38
    // Juz 20 (Hizb 39-40)
    [27, 56], [27, 82], [28, 12], [28, 29], // Hizb 39
    [28, 51], [28, 76], [29, 1], [29, 26], // Hizb 40
    // Juz 21 (Hizb 41-42)
    [29, 46], [30, 1], [30, 31], [30, 54], // Hizb 41
    [31, 22], [32, 11], [33, 1], [33, 18], // Hizb 42
    // Juz 22 (Hizb 43-44)
    [33, 31], [33, 51], [33, 60], [34, 10], // Hizb 43
    [34, 24], [34, 46], [35, 15], [35, 41], // Hizb 44
    // Juz 23 (Hizb 45-46)
    [36, 28], [36, 60], [37, 22], [37, 83], // Hizb 45
    [37, 145], [38, 21], [38, 52], [39, 8], // Hizb 46
    // Juz 24 (Hizb 47-48)
    [39, 32], [39, 53], [40, 1], [40, 21], // Hizb 47
    [40, 41], [40, 66], [41, 1], [41, 25], // Hizb 48
    // Juz 25 (Hizb 49-50)
    [41, 47], [42, 13], [42, 27], [42, 51], // Hizb 49
    [43, 24], [43, 57], [44, 17], [45, 12], // Hizb 50
    // Juz 26 (Hizb 51-52)
    [46, 1], [46, 21], [47, 10], [47, 33], // Hizb 51
    [48, 18], [49, 1], [49, 14], [50, 27], // Hizb 52
    // Juz 27 (Hizb 53-54)
    [51, 31], [52, 24], [53, 26], [54, 1], // Hizb 53
    [55, 1], [55, 46], [56, 39], [57, 1], // Hizb 54
    // Juz 28 (Hizb 55-56)
    [58, 1], [58, 14], [59, 11], [60, 7], // Hizb 55
    [61, 14], [63, 4], [65, 1], [66, 1], // Hizb 56
    // Juz 29 (Hizb 57-58)
    [67, 1], [68, 16], [69, 24], [70, 19], // Hizb 57
    [72, 1], [73, 20], [75, 1], [76, 19], // Hizb 58
    // Juz 30 (Hizb 59-60)
    [78, 1], [79, 27], [81, 1], [83, 7], // Hizb 59
    [86, 1], [90, 1], [93, 1], [97, 1], // Hizb 60
  ];

  /// Quarter (Rub') start pages — 240 quarters total.
  /// Uses actual Madinah mushaf hizb quarter markers.
  static List<int> get quarterStartPages {
    return _quarterMarkers.map((m) => quran.getPageNumber(m[0], m[1])).toList();
  }

  /// Returns a WirdSession with precise boundaries.
  static WirdSession getSession({
    required int sessionIndex,
    required int totalSessions,
    WirdUnit unit = WirdUnit.page,
    int startFromPage = 1,
  }) {
    int totalPages;

    // ─── Juz-based distribution ───
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

    // ─── Quarter-based distribution ───
    if (unit == WirdUnit.quarter) {
      final qPages = quarterStartPages;
      int startQuarterIndex = 0;
      for (int i = qPages.length - 1; i >= 0; i--) {
        if (startFromPage >= qPages[i]) {
          startQuarterIndex = i;
          break;
        }
      }
      int totalQuarters = 240 - startQuarterIndex;

      if (sessionIndex >= totalSessions) {
        sessionIndex = totalSessions - 1;
      }

      int baseQ = totalQuarters ~/ totalSessions;
      int extraQ = totalQuarters % totalSessions;

      List<int> sessionSizes = List.filled(totalSessions, baseQ);
      if (extraQ > 0) {
        int remaining = extraQ;
        if (startQuarterIndex == 0 && remaining > 0) {
          sessionSizes[0]++;
          remaining--;
        }
        for (int i = 0; i < remaining; i++) {
          int targetIndex = totalSessions - 1 - i;
          if (targetIndex >= 0 && targetIndex < totalSessions) {
            sessionSizes[targetIndex]++;
          }
        }
      }

      int startQ = startQuarterIndex;
      for (int i = 0; i < sessionIndex; i++) {
        startQ += sessionSizes[i];
      }
      int endQ = startQ + sessionSizes[sessionIndex] - 1;

      if (startQ >= 240) startQ = 239;
      if (endQ >= 240) endQ = 239;

      int sPage = qPages[startQ];
      int ePage = (endQ + 1 < 240) ? (qPages[endQ + 1] - 1) : 604;
      if (ePage < sPage) ePage = sPage;

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

    // ─── Page-based distribution ───
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

  static int getRemainingQuarters(int startJuz) {
    if (startJuz <= 1) return 240;
    if (startJuz > 30) return 0;
    return (31 - startJuz) * 8;
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
      case WirdUnit.quarter:
        pagesPerUnit = 5; // ~5 pages per quarter (rub')
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
