import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_surah_model.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran/surah_data.dart';

import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import './fehres_items_list_view.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Parses "surah:verse" key (e.g. "2:141") into [surah, verse].
List<int> _parseVerseKey(String key) {
  final parts = key.split(':');
  return [int.parse(parts[0]), int.parse(parts[1])];
}

/// Navigates to the page corresponding to [verseKey] (e.g. "2:1") and
/// highlights the target verse, matching bookmarks/search behaviour.
void _navigateToVerseKey(BuildContext context, String verseKey) {
  try {
    final parts = _parseVerseKey(verseKey);
    final surahNum = parts[0];
    final verseNum = parts[1];
    Navigator.pop(context);
    context.read<QuranCubit>().navigateToVerse(
      surahNumber: surahNum,
      verseNumber: verseNum,
    );
  } catch (e) {
    debugPrint('Error navigating to verse key: $e');
  }
}

/// Returns the first [wordCount] words of an Arabic string.
String _firstWords(String text, {int wordCount = 5}) {
  final words = text.trim().split(RegExp(r'\s+'));
  return words.take(wordCount).join(' ');
}

// ── Stateful dialog (needs async JSON loading) ────────────────────────────────

class QuranFehresDialog extends StatefulWidget {
  const QuranFehresDialog({super.key});

  @override
  State<QuranFehresDialog> createState() => _QuranFehresDialogState();
}

class _QuranFehresDialogState extends State<QuranFehresDialog> {
  // Surah tab
  final ValueNotifier<List<SearchingSurahModel>> _surahsNotifier =
      ValueNotifier([]);

  // JSON metadata
  List<Map<String, dynamic>> _juzData = [];
  List<Map<String, dynamic>> _hizbData = [];
  List<Map<String, dynamic>> _rubData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSurahs(),
      _loadJson(
        'assets/data/quran-metadata-juz.json',
        30,
      ).then((v) => _juzData = v),
      _loadJson(
        'assets/data/quran-metadata-hizb.json',
        60,
      ).then((v) => _hizbData = v),
      _loadJson(
        'assets/data/quran-metadata-rub.json',
        240,
      ).then((v) => _rubData = v),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _loadJson(String path, int count) async {
    final raw = await rootBundle.loadString(path);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final result = <Map<String, dynamic>>[];
    for (int i = 1; i <= count; i++) {
      final entry = decoded['$i'];
      if (entry != null) result.add(Map<String, dynamic>.from(entry as Map));
    }
    return result;
  }

  Future<void> _loadSurahs({String? query}) async {
    final list = query == null || query.isEmpty
        ? surah.map((e) => SearchingSurahModel.fromMap(e)).toList()
        : surah
              .where((e) => (e['arabic'] as String).startsWith(query))
              .map((e) => SearchingSurahModel.fromMap(e))
              .toList();
    _surahsNotifier.value = list;
  }

  @override
  Widget build(BuildContext context) {
    final quranState = context.read<QuranCubit>().state;
    final paperColor = quranState.isWirdMode
        ? quranState.wirdPaperColor
        : quranState.quranPaperColor;
    
    // The dialog body background follows the Mushaf paper's brightness
    final bool isPaperDark = (paperColor ?? Colors.white).computeLuminance() < 0.5;
    
    // Use true black for dark mode in index
    final Color dialogBg = isPaperDark ? const Color(0xFF000000) : Colors.white;
    final Color primary = Theme.of(context).primaryColor;
    final Color headerBg = primary;
    final Color onSurface = isPaperDark ? Colors.white : Colors.black87;

    final int currentPage = context.watch<QuranCubit>().state.currentPage ?? 0;
    int activeJuz = 0;
    int activeHizb = 0;
    int activeRub = 0;
    try {
      final cp = currentPage + 1;
      final pageData = quran.getPageData(cp);
      if (pageData.isNotEmpty) {
        final currentSurah = pageData[0]['surah'];
        final currentVerse = pageData[0]['start'];
        activeJuz = quran.getJuzNumber(currentSurah, currentVerse);
      }

      if (_rubData.isNotEmpty) {
        for (int i = 0; i < _rubData.length; i++) {
          final verseKey = _rubData[i]['first_verse_key'] as String;
          final parts = verseKey.split(':');
          final p = quran.getPageNumber(
            int.tryParse(parts[0]) ?? 1,
            int.tryParse(parts[1]) ?? 1,
          );
          if (p <= cp) activeRub = i + 1;
        }
      }
      if (_hizbData.isNotEmpty) {
        for (int i = 0; i < _hizbData.length; i++) {
          final verseKey = _hizbData[i]['first_verse_key'] as String;
          final parts = verseKey.split(':');
          final p = quran.getPageNumber(
            int.tryParse(parts[0]) ?? 1,
            int.tryParse(parts[1]) ?? 1,
          );
          if (p <= cp) activeHizb = i + 1;
        }
      }
    } catch (e) {
      debugPrint('Error calculating active hizb/rub: $e');
    }

    const TextStyle tabLabel = TextStyle(
      fontFamily: 'Cairo',
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    const TextStyle tabUnselected = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 12,
    );

    return Dialog(
      child: DefaultTabController(
        length: 4,
        child: Container(
          width: context.screenWidth * .88,
          height: context.screenHeight * .78,
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'فهرس القرآن',
                  style: AppStyles.style16.copyWith(color: Colors.white),
                ),
              ),

              // ── TabBar ─────────────────────────────────────────────────────
              TabBar(
                indicatorColor: primary,
                labelColor: primary,
                unselectedLabelColor: onSurface.withValues(alpha: 0.6),
                labelStyle: tabLabel,
                unselectedLabelStyle: tabUnselected,
                tabs: const [
                  Tab(text: 'السور'),
                  Tab(text: 'الأجزاء'),
                  Tab(text: 'الأحزاب'),
                  Tab(text: 'الأرباع'),
                ],
              ),

              // ── Body ───────────────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? ListView.builder(
                        itemCount: 8,
                        itemBuilder: (_, __) => AppSkeleton.indexItem(),
                      )
                    : TabBarView(
                        children: [
                          // Tab 1: السور
                          _SurahTab(
                            notifier: _surahsNotifier,
                            onSearch: (q) => _loadSurahs(query: q),
                            onSurface: onSurface,
                          ),

                          // Tab 2: الأجزاء (30 items)
                          _MetadataListTab(
                            items: _juzData,
                            labelBuilder: (i, _) => (i + 1).toJuzName,
                            subtitleBuilder: (i, item) =>
                                'صفحة ${_pageForKey(item['first_verse_key'] as String).toArabicNums}',
                            onSurface: onSurface,
                            activeJuz: activeJuz,
                            onTap: (ctx, item) => _navigateToVerseKey(
                              ctx,
                              item['first_verse_key'] as String,
                            ),
                          ),

                          // Tab 3: الأحزاب – grouped card UI
                          _HizbTab(
                            hizbData: _hizbData,
                            onSurface: onSurface,
                            isLightBg: !isPaperDark,
                            activeHizb: activeHizb,
                          ),

                          // Tab 4: الأرباع – grouped + rich card UI
                          _RubTab(
                            rubData: _rubData,
                            onSurface: onSurface,
                            isLightBg: !isPaperDark,
                            activeRub: activeRub,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _pageForKey(String verseKey) {
    try {
      final parts = _parseVerseKey(verseKey);
      return quran.getPageNumber(parts[0], parts[1]);
    } catch (_) {
      return 1;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 – السور
// ─────────────────────────────────────────────────────────────────────────────

class _SurahTab extends StatelessWidget {
  final ValueNotifier<List<SearchingSurahModel>> notifier;
  final void Function(String) onSearch;
  final Color onSurface;

  const _SurahTab({
    required this.notifier,
    required this.onSearch,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: context.bodySmall.copyWith(color: onSurface),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة',
              hintStyle: context.bodySmall.copyWith(
                color: onSurface.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onSearch,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ValueListenableBuilder<List<SearchingSurahModel>>(
            valueListenable: notifier,
            builder: (context, surahs, _) =>
                FehresItemsListView(surahs: surahs),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 & 3 – Generic metadata list (Juz / Hizb)
// ─────────────────────────────────────────────────────────────────────────────

class _MetadataListTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(int index, Map<String, dynamic> item) labelBuilder;
  final String Function(int index, Map<String, dynamic> item) subtitleBuilder;
  final void Function(BuildContext context, Map<String, dynamic> item) onTap;
  final Color onSurface;
  final int activeJuz;

  const _MetadataListTab({
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.onTap,
    required this.onSurface,
    required this.activeJuz,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark;
    final Color activeTextColor = isPrimaryDark ? Colors.white : Colors.black87;
    
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(color: onSurface.withValues(alpha: 0.12), height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isActive = (index + 1) == activeJuz;
        final Color bgColor = isActive ? primary : Colors.transparent;
        final Color txtColor = isActive ? activeTextColor : onSurface;
        final Color subTxtColor = isActive
            ? activeTextColor.withValues(alpha: 0.7)
            : onSurface.withValues(alpha: 0.6);

        return ColoredBox(
          color: bgColor,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? activeTextColor.withValues(alpha: 0.2)
                  : primary.withValues(alpha: 0.14),
              child: Text(
                (index + 1).toArabicNums,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: isActive ? activeTextColor : primary,
                  fontSize: 13,
                ),
              ),
            ),
            title: Text(
              labelBuilder(index, item),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: txtColor,
                fontSize: 15,
              ),
            ),
            leading: Text(
              subtitleBuilder(index, item),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: subTxtColor,
                fontSize: 12,
              ),
            ),
            onTap: () => onTap(context, item),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 – الأرباع  (professional grouped card list)
// ─────────────────────────────────────────────────────────────────────────────

/// Data class for a single Rub' row.
class _RubEntry {
  final int rubIndex; // 0-based (0..239)
  final int surahNum;
  final int verseNum;
  final int pageNum;
  final String verseText; // first 5 words of the verse
  final String surahName;
  final int juzNum; // 1-based
  final bool isHizbStart; // every 4th rub (index % 4 == 0 && index != 0)
  final int hizbNum; // 1-based hizb number

  const _RubEntry({
    required this.rubIndex,
    required this.surahNum,
    required this.verseNum,
    required this.pageNum,
    required this.verseText,
    required this.surahName,
    required this.juzNum,
    required this.isHizbStart,
    required this.hizbNum,
  });
}

/// Builds a list of [_RubEntry] from the decoded JSON rows.
List<_RubEntry> _buildRubEntries(List<Map<String, dynamic>> rubData) {
  final entries = <_RubEntry>[];
  for (int i = 0; i < rubData.length; i++) {
    final item = rubData[i];
    final verseKey = item['first_verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 1;
    final verseNum = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;

    int pageNum = 1;
    String verseText = '';
    try {
      pageNum = quran.getPageNumber(surahNum, verseNum);
      final raw = quran.getVerse(surahNum, verseNum, verseEndSymbol: false);
      verseText = _firstWords(raw, wordCount: 8);
    } catch (e) {
      debugPrint('Error fetching Rub verse text: $e');
    }

    final surahName = quran.getSurahNameArabic(surahNum);
    final juzNum = (i ~/ 8) + 1;
    // Hizb starts every 4 quarters.
    final isHizbStart = (i % 4 == 0);
    final hizbNum = (i ~/ 4) + 1;

    entries.add(
      _RubEntry(
        rubIndex: i,
        surahNum: surahNum,
        verseNum: verseNum,
        pageNum: pageNum,
        verseText: verseText,
        surahName: surahName,
        juzNum: juzNum,
        isHizbStart: isHizbStart,
        hizbNum: hizbNum,
      ),
    );
  }
  return entries;
}

class _RubTab extends StatefulWidget {
  final List<Map<String, dynamic>> rubData;
  final Color onSurface;
  final bool isLightBg;
  final int activeRub;

  const _RubTab({
    required this.rubData,
    required this.onSurface,
    required this.isLightBg,
    required this.activeRub,
  });

  @override
  State<_RubTab> createState() => _RubTabState();
}

class _RubTabState extends State<_RubTab> {
  late final List<_RubEntry> _entries;

  @override
  void initState() {
    super.initState();
    // Build once – pure computation, no async needed.
    _entries = _buildRubEntries(widget.rubData);
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => AppSkeleton.indexItem(),
      );
    }

    // Build a flat list interleaved with Juz headers.
    // Pool: [juz_header | rub_card, rub_card, …×8 ] × 30
    final List<Widget> rows = [];
    int currentJuz = 0;

    for (final entry in _entries) {
      if (entry.juzNum != currentJuz) {
        currentJuz = entry.juzNum;
        rows.add(_JuzHeader(juzNum: currentJuz, isLightBg: widget.isLightBg));
      }
      rows.add(
        _RubCard(
          entry: entry,
          onSurface: widget.onSurface,
          isLightBg: widget.isLightBg,
          activeRub: widget.activeRub,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}

// ── Juz section header ────────────────────────────────────────────────────────

class _JuzHeader extends StatelessWidget {
  final int juzNum;
  final bool isLightBg;

  const _JuzHeader({required this.juzNum, required this.isLightBg});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isLightBg ? 0.08 : 0.18),
        border: Border(right: BorderSide(color: primary, width: 3)),
      ),
      child: Text(
        juzNum.toJuzName,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontWeight: FontWeight.bold,
          color: primary,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ── Individual Rub' card ──────────────────────────────────────────────────────

class _RubCard extends StatelessWidget {
  final _RubEntry entry;
  final Color onSurface;
  final bool isLightBg;
  final int activeRub;

  const _RubCard({
    required this.entry,
    required this.onSurface,
    required this.isLightBg,
    required this.activeRub,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark;
    final Color activeTextColor = isPrimaryDark ? Colors.white : Colors.black87;

    final bool isActive = (entry.rubIndex + 1) == activeRub;
    final cardBg = isActive
        ? primary
        : (isLightBg ? Colors.white : const Color(0xFF000000));
    final txtColor = isActive ? activeTextColor : onSurface;
    final subTxtColor = isActive ? activeTextColor.withValues(alpha: 0.8) : onSurface.withAlpha(150);

    // Quarter number within the Hizb (0, 1, 2, 3)
    final quarterInHizb = entry.rubIndex % 4;

    String quarterLabel = '';
    switch (quarterInHizb) {
      case 0:
        quarterLabel = 'مبدأ';
        break;
      case 1:
        quarterLabel = 'الربع';
        break;
      case 2:
        quarterLabel = 'النصف';
        break;
      case 3:
        quarterLabel = 'الثلاثة أرباع';
        break;
    }

    return InkWell(
      onTap: () =>
          _navigateToVerseKey(context, '${entry.surahNum}:${entry.verseNum}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          // Clean solid look without borders
          boxShadow: isLightBg && !isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Right: Rub' marker icon ─────────────────────────────────
              SizedBox(
                width: 45, // Allocate fixed width to keep text aligned
                child: _RubMarker(
                  entry: entry,
                  primary: isActive ? Colors.white : primary,
                  quarterLabel: quarterLabel,
                ),
              ),

              const SizedBox(width: 10),

              // ── Center: Verse text + subtitle ───────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Verse snippet in Uthmanic font
                    Text(
                      entry.verseText.isEmpty ? '...' : '${entry.verseText}…',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppConsts.amiri,
                        fontSize: 18,
                        height: 1.8,
                        color: txtColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'الصفحة ${entry.pageNum.toArabicNums}',
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            color: subTxtColor,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'سورة ${entry.surahName}',
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            color: subTxtColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rub' marker — 8 Pointed Star ─────────────────────────────────────────────

class _IslamicStarPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double fillFraction;

  const _IslamicStarPainter({
    required this.primaryColor,
    required this.secondaryColor,
    this.fillFraction = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // width of the square that fits in the bounding circle
    final rectWidth = radius * 1.414;

    // 1. Draw Outline (Background Shape)
    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.save();
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: rectWidth, height: rectWidth),
      strokePaint,
    );
    canvas.restore();
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: rectWidth, height: rectWidth),
      strokePaint,
    );
    canvas.restore();

    if (fillFraction <= 0) return;

    // 2. Draw Filled portion
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Create a path containing the quadrants to fill
    final clipPath = Path();
    // top-right:
    final tr = Rect.fromLTRB(0, -size.height, size.width, 0);
    // bottom-right:
    final br = Rect.fromLTRB(0, 0, size.width, size.height);
    // bottom-left:
    final bl = Rect.fromLTRB(-size.width, 0, 0, size.height);
    // top-left:
    final tl = Rect.fromLTRB(-size.width, -size.height, 0, 0);

    // Clockwise fill starting from Top-Right (standard Arabic RTL visual weight)
    if (fillFraction >= 0.25) clipPath.addRect(tr);
    if (fillFraction >= 0.50) clipPath.addRect(br);
    if (fillFraction >= 0.75) clipPath.addRect(bl);
    if (fillFraction >= 1.00) clipPath.addRect(tl);

    canvas.clipPath(clipPath);

    final paint1 = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    // Draw rotated square first (secondary color)
    canvas.save();
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: rectWidth - 1,
        height: rectWidth - 1,
      ),
      paint1,
    );
    canvas.restore();

    // Draw straight square on top (primary color)
    canvas.save();
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: rectWidth - 1,
        height: rectWidth - 1,
      ),
      paint2,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IslamicStarPainter old) =>
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.fillFraction != fillFraction;
}

class _RubMarker extends StatelessWidget {
  final _RubEntry entry;
  final Color primary;
  final String quarterLabel;

  const _RubMarker({
    required this.entry,
    required this.primary,
    required this.quarterLabel,
  });

  @override
  Widget build(BuildContext context) {
    const Color starPrimary = Color(0xFFD4AF37);
    const Color starSecondary = Color(0xFFB8860B);

    final size = entry.isHizbStart ? 34.0 : 26.0;

    // Fraction logic
    final double fill = entry.isHizbStart
        ? 1.0
        : switch (quarterLabel) {
          'الربع' => 0.25,
          'النصف' => 0.5,
          'الثلاثة أرباع' => 0.75,
          _ => 1.0,
        };

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _IslamicStarPainter(
              primaryColor: starPrimary,
              secondaryColor: starSecondary,
              fillFraction: fill,
            ),
            child: entry.isHizbStart
                ? Center(
                    child: Text(
                      entry.hizbNum.toArabicNums,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConsts.cairo,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        if (entry.isHizbStart) ...[
          const SizedBox(height: 6),
          Text(
            'الحزب',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 – الأحزاب  (professional grouped card list)
// ─────────────────────────────────────────────────────────────────────────────

class _HizbEntry {
  final int hizbIndex;
  final int surahNum;
  final int verseNum;
  final int pageNum;
  final String verseText;
  final String surahName;
  final int juzNum; // every 2 ahzab = 1 juz

  const _HizbEntry({
    required this.hizbIndex,
    required this.surahNum,
    required this.verseNum,
    required this.pageNum,
    required this.verseText,
    required this.surahName,
    required this.juzNum,
  });
}

List<_HizbEntry> _buildHizbEntries(List<Map<String, dynamic>> hizbData) {
  final entries = <_HizbEntry>[];
  for (int i = 0; i < hizbData.length; i++) {
    final item = hizbData[i];
    final verseKey = item['first_verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 1;
    final verseNum = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;

    int pageNum = 1;
    String verseText = '';
    try {
      pageNum = quran.getPageNumber(surahNum, verseNum);
      final raw = quran.getVerse(surahNum, verseNum, verseEndSymbol: false);
      verseText = _firstWords(raw, wordCount: 8);
    } catch (e) {
      debugPrint('Error fetching Hizb verse text: $e');
    }

    final surahName = quran.getSurahNameArabic(surahNum);
    final juzNum = (i ~/ 2) + 1;

    entries.add(
      _HizbEntry(
        hizbIndex: i,
        surahNum: surahNum,
        verseNum: verseNum,
        pageNum: pageNum,
        verseText: verseText,
        surahName: surahName,
        juzNum: juzNum,
      ),
    );
  }
  return entries;
}

class _HizbTab extends StatefulWidget {
  final List<Map<String, dynamic>> hizbData;
  final Color onSurface;
  final bool isLightBg;
  final int activeHizb;

  const _HizbTab({
    required this.hizbData,
    required this.onSurface,
    required this.isLightBg,
    required this.activeHizb,
  });

  @override
  State<_HizbTab> createState() => _HizbTabState();
}

class _HizbTabState extends State<_HizbTab> {
  late final List<_HizbEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _buildHizbEntries(widget.hizbData);
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => AppSkeleton.indexItem(),
      );
    }

    final List<Widget> rows = [];
    int currentJuz = 0;

    for (final entry in _entries) {
      if (entry.juzNum != currentJuz) {
        currentJuz = entry.juzNum;
        rows.add(_JuzHeader(juzNum: currentJuz, isLightBg: widget.isLightBg));
      }
      rows.add(
        _HizbCard(
          entry: entry,
          onSurface: widget.onSurface,
          isLightBg: widget.isLightBg,
          activeHizb: widget.activeHizb,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}

class _HizbCard extends StatelessWidget {
  final _HizbEntry entry;
  final Color onSurface;
  final bool isLightBg;
  final int activeHizb;

  const _HizbCard({
    required this.entry,
    required this.onSurface,
    required this.isLightBg,
    required this.activeHizb,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark;
    final Color activeTextColor = isPrimaryDark ? Colors.white : Colors.black87;

    final bool isActive = (entry.hizbIndex + 1) == activeHizb;
    final cardBg = isActive
        ? primary
        : (isLightBg ? Colors.white : const Color(0xFF000000));
    final txtColor = isActive ? activeTextColor : onSurface;
    final subTxtColor = isActive ? activeTextColor.withValues(alpha: 0.8) : onSurface.withAlpha(150);
    final hizbInJuz = (entry.hizbIndex % 2) + 1;
    final hizbLabel = hizbInJuz == 1 ? 'الحزب الأول' : 'الحزب الثاني';

    return InkWell(
      onTap: () =>
          _navigateToVerseKey(context, '${entry.surahNum}:${entry.verseNum}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isLightBg && !isActive
              ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HizbMarker(
                hizbNum: entry.hizbIndex + 1,
                primary: isActive ? Colors.white : primary,
                label: hizbLabel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.verseText.isEmpty ? '...' : '${entry.verseText}…',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppConsts.amiri,
                        fontSize: 18,
                        height: 1.8,
                        color: txtColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'الصفحة ${entry.pageNum.toArabicNums}',
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            color: subTxtColor,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'سورة ${entry.surahName}',
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            color: subTxtColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HizbMarker extends StatelessWidget {
  final int hizbNum;
  final Color primary;
  final String label;

  const _HizbMarker({
    required this.hizbNum,
    required this.primary,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const Color starPrimary = Color(0xFFD4AF37);
    const Color starSecondary = Color(0xFFB8860B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34.0,
          height: 34.0,
          child: CustomPaint(
            painter: const _IslamicStarPainter(
              primaryColor: starPrimary,
              secondaryColor: starSecondary,
            ),
            child: Center(
              child: Text(
                hizbNum.toArabicNums,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'الحزب',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    );
  }
}
