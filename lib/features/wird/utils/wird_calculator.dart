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
    122,
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

  /// Precise Rub' al-Hizb boundaries from quran-metadata-rub.json
  /// Each entry: [startSurah, startAyah, endSurah, endAyah]
  /// 240 rub's total (60 hizb × 4 quarters each)
  static const List<List<int>> _rubMarkers = [
    // rub 1–10
    [1, 1, 2, 25],
    [2, 26, 2, 43],
    [2, 44, 2, 59],
    [2, 60, 2, 74],
    [2, 75, 2, 91],
    [2, 92, 2, 105],
    [2, 106, 2, 123],
    [2, 124, 2, 141],
    [2, 142, 2, 157],
    [2, 158, 2, 176],
    // rub 11–20
    [2, 177, 2, 188],
    [2, 189, 2, 202],
    [2, 203, 2, 218],
    [2, 219, 2, 232],
    [2, 233, 2, 242],
    [2, 243, 2, 252],
    [2, 253, 2, 262],
    [2, 263, 2, 271],
    [2, 272, 2, 282],
    [2, 283, 3, 14],
    // rub 21–30
    [3, 15, 3, 32],
    [3, 33, 3, 51],
    [3, 52, 3, 74],
    [3, 75, 3, 92],
    [3, 93, 3, 112],
    [3, 113, 3, 132],
    [3, 133, 3, 152],
    [3, 153, 3, 170],
    [3, 171, 3, 185],
    [3, 186, 3, 200],
    // rub 31–40
    [4, 1, 4, 11],
    [4, 12, 4, 23],
    [4, 24, 4, 35],
    [4, 36, 4, 57],
    [4, 58, 4, 73],
    [4, 74, 4, 87],
    [4, 88, 4, 99],
    [4, 100, 4, 113],
    [4, 114, 4, 134],
    [4, 135, 4, 147],
    // rub 41–50
    [4, 148, 4, 162],
    [4, 163, 4, 176],
    [5, 1, 5, 11],
    [5, 12, 5, 26],
    [5, 27, 5, 40],
    [5, 41, 5, 50],
    [5, 51, 5, 66],
    [5, 67, 5, 81],
    [5, 82, 5, 96],
    [5, 97, 5, 108],
    // rub 51–60
    [5, 109, 6, 12],
    [6, 13, 6, 35],
    [6, 36, 6, 58],
    [6, 59, 6, 73],
    [6, 74, 6, 94],
    [6, 95, 6, 110],
    [6, 111, 6, 126],
    [6, 127, 6, 140],
    [6, 141, 6, 150],
    [6, 151, 6, 165],
    // rub 61–70
    [7, 1, 7, 30],
    [7, 31, 7, 46],
    [7, 47, 7, 64],
    [7, 65, 7, 87],
    [7, 88, 7, 116],
    [7, 117, 7, 141],
    [7, 142, 7, 155],
    [7, 156, 7, 170],
    [7, 171, 7, 188],
    [7, 189, 7, 206],
    // rub 71–80
    [8, 1, 8, 21],
    [8, 22, 8, 40],
    [8, 41, 8, 60],
    [8, 61, 8, 75],
    [9, 1, 9, 18],
    [9, 19, 9, 33],
    [9, 34, 9, 45],
    [9, 46, 9, 59],
    [9, 60, 9, 74],
    [9, 75, 9, 92],
    // rub 81–90
    [9, 93, 9, 110],
    [9, 111, 9, 121],
    [9, 122, 10, 10],
    [10, 11, 10, 25],
    [10, 26, 10, 52],
    [10, 53, 10, 70],
    [10, 71, 10, 89],
    [10, 90, 11, 5],
    [11, 6, 11, 23],
    [11, 24, 11, 40],
    // rub 91–100
    [11, 41, 11, 60],
    [11, 61, 11, 83],
    [11, 84, 11, 107],
    [11, 108, 12, 6],
    [12, 7, 12, 29],
    [12, 30, 12, 52],
    [12, 53, 12, 76],
    [12, 77, 12, 100],
    [12, 101, 13, 4],
    [13, 5, 13, 18],
    // rub 101–110
    [13, 19, 13, 34],
    [13, 35, 14, 9],
    [14, 10, 14, 27],
    [14, 28, 14, 52],
    [15, 1, 15, 48],
    [15, 49, 15, 99],
    [16, 1, 16, 29],
    [16, 30, 16, 50],
    [16, 51, 16, 74],
    [16, 75, 16, 89],
    // rub 111–120
    [16, 90, 16, 110],
    [16, 111, 16, 128],
    [17, 1, 17, 22],
    [17, 23, 17, 49],
    [17, 50, 17, 69],
    [17, 70, 17, 98],
    [17, 99, 18, 16],
    [18, 17, 18, 31],
    [18, 32, 18, 50],
    [18, 51, 18, 74],
    // rub 121–130
    [18, 75, 18, 98],
    [18, 99, 19, 21],
    [19, 22, 19, 58],
    [19, 59, 19, 98],
    [20, 1, 20, 54],
    [20, 55, 20, 82],
    [20, 83, 20, 110],
    [20, 111, 20, 135],
    [21, 1, 21, 28],
    [21, 29, 21, 50],
    // rub 131–140
    [21, 51, 21, 82],
    [21, 83, 21, 112],
    [22, 1, 22, 18],
    [22, 19, 22, 37],
    [22, 38, 22, 59],
    [22, 60, 22, 78],
    [23, 1, 23, 35],
    [23, 36, 23, 74],
    [23, 75, 23, 118],
    [24, 1, 24, 20],
    // rub 141–150
    [24, 21, 24, 34],
    [24, 35, 24, 52],
    [24, 53, 24, 64],
    [25, 1, 25, 20],
    [25, 21, 25, 52],
    [25, 53, 25, 77],
    [26, 1, 26, 51],
    [26, 52, 26, 110],
    [26, 111, 26, 180],
    [26, 181, 26, 227],
    // rub 151–160
    [27, 1, 27, 26],
    [27, 27, 27, 55],
    [27, 56, 27, 81],
    [27, 82, 28, 11],
    [28, 12, 28, 28],
    [28, 29, 28, 50],
    [28, 51, 28, 75],
    [28, 76, 28, 88],
    [29, 1, 29, 25],
    [29, 26, 29, 45],
    // rub 161–170
    [29, 46, 29, 69],
    [30, 1, 30, 30],
    [30, 31, 30, 53],
    [30, 54, 31, 21],
    [31, 22, 32, 10],
    [32, 11, 32, 30],
    [33, 1, 33, 17],
    [33, 18, 33, 30],
    [33, 31, 33, 50],
    [33, 51, 33, 59],
    // rub 171–180
    [33, 60, 34, 9],
    [34, 10, 34, 23],
    [34, 24, 34, 45],
    [34, 46, 35, 14],
    [35, 15, 35, 40],
    [35, 41, 36, 27],
    [36, 28, 36, 59],
    [36, 60, 37, 21],
    [37, 22, 37, 82],
    [37, 83, 37, 144],
    // rub 181–190
    [37, 145, 38, 20],
    [38, 21, 38, 51],
    [38, 52, 39, 7],
    [39, 8, 39, 31],
    [39, 32, 39, 52],
    [39, 53, 39, 75],
    [40, 1, 40, 20],
    [40, 21, 40, 40],
    [40, 41, 40, 65],
    [40, 66, 41, 8],
    // rub 191–200
    [41, 9, 41, 24],
    [41, 25, 41, 46],
    [41, 47, 42, 12],
    [42, 13, 42, 26],
    [42, 27, 42, 50],
    [42, 51, 43, 23],
    [43, 24, 43, 56],
    [43, 57, 44, 16],
    [44, 17, 45, 11],
    [45, 12, 45, 37],
    // rub 201–210
    [46, 1, 46, 20],
    [46, 21, 47, 9],
    [47, 10, 47, 32],
    [47, 33, 48, 17],
    [48, 18, 48, 29],
    [49, 1, 49, 13],
    [49, 14, 50, 26],
    [50, 27, 51, 30],
    [51, 31, 52, 23],
    [52, 24, 53, 25],
    // rub 211–220
    [53, 26, 54, 8],
    [54, 9, 54, 55],
    [55, 1, 55, 78],
    [56, 1, 56, 74],
    [56, 75, 57, 15],
    [57, 16, 57, 29],
    [58, 1, 58, 13],
    [58, 14, 59, 10],
    [59, 11, 60, 6],
    [60, 7, 61, 14],
    // rub 221–230
    [62, 1, 63, 3],
    [63, 4, 64, 18],
    [65, 1, 65, 12],
    [66, 1, 66, 12],
    [67, 1, 67, 30],
    [68, 1, 68, 52],
    [69, 1, 70, 18],
    [70, 19, 71, 28],
    [72, 1, 73, 19],
    [73, 20, 74, 56],
    // rub 231–240
    [75, 1, 76, 18],
    [76, 19, 77, 50],
    [78, 1, 79, 46],
    [80, 1, 81, 29],
    [82, 1, 83, 36],
    [84, 1, 86, 17],
    [87, 1, 89, 30],
    [90, 1, 93, 11],
    [94, 1, 100, 8],
    [100, 9, 114, 6],
  ];

  /// Returns the number of remaining quarters from [startFromPage] to end of Quran.
  static int getQuarterCount(int startFromPage) {
    int startQIdx = 0;
    for (int i = _rubMarkers.length - 1; i >= 0; i--) {
      final sp = quran.getPageNumber(_rubMarkers[i][0], _rubMarkers[i][1]);
      if (startFromPage >= sp) {
        startQIdx = i;
        break;
      }
    }
    return 240 - startQIdx;
  }

  /// Quarter (Rub') start pages — 240 quarters total.
  static List<int> get quarterStartPages {
    return _rubMarkers.map((m) => quran.getPageNumber(m[0], m[1])).toList();
  }

  /// Returns a WirdSession with precise boundaries.
  static WirdSession getSession({
    required int sessionIndex,
    required int totalSessions,
    WirdUnit unit = WirdUnit.page,
    int startFromPage = 1,
  }) {
    // ─── Juz-based distribution ───
    if (unit == WirdUnit.juz) {
      int targetJuz = sessionIndex.clamp(0, 29);

      int sPage = juzStartPages[targetJuz];
      int ePage = (targetJuz == 29) ? 604 : juzStartPages[targetJuz + 1] - 1;

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
    // Each session = exactly ONE Rub' from quran-metadata-rub.json.
    // sessionIndex maps 1:1 to a rub'; no merging or redistribution.
    if (unit == WirdUnit.quarter) {
      // Find the first rub' index whose start page >= startFromPage
      int startQIdx = 0;
      for (int i = _rubMarkers.length - 1; i >= 0; i--) {
        final sp = quran.getPageNumber(_rubMarkers[i][0], _rubMarkers[i][1]);
        if (startFromPage >= sp) {
          startQIdx = i;
          break;
        }
      }

      int targetQ = (startQIdx + sessionIndex).clamp(0, 239);
      final m = _rubMarkers[targetQ];

      // Use EXACT verse boundaries from JSON data
      int sPage = quran.getPageNumber(m[0], m[1]);
      int ePage = quran.getPageNumber(m[2], m[3]);
      if (ePage < sPage) ePage = sPage;

      return WirdSession(
        startPage: sPage,
        endPage: ePage,
        isPartial: true,
        startSuraNumber: m[0],
        startAyah: m[1],
        endSuraNumber: m[2],
        endAyah: m[3],
      );
    }

    // ─── Page-based distribution ───
    int totalPages = 604 - startFromPage + 1;
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
        pagesPerUnit = 5; // ~5 pages per rub'
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
