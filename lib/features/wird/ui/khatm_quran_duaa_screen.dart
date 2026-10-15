import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/share_helper.dart';
import '../data/khatm_quran_duaa.dart';

class KhatmQuranDuaaScreen extends StatefulWidget {
  const KhatmQuranDuaaScreen({super.key});

  @override
  State<KhatmQuranDuaaScreen> createState() => _KhatmQuranDuaaScreenState();
}

class _KhatmQuranDuaaScreenState extends State<KhatmQuranDuaaScreen> {
  double _fontSize = 20.0;
  final GlobalKey _cardExportKey = GlobalKey();

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: KhatmQuranDuaa.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم نسخ دعاء ختم القرآن الكريم بنجاح",
          style: TextStyle(fontFamily: AppConsts.cairo),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Color(0xFFD0A871),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareText() {
    SharePlus.instance.share(
      ShareParams(
        text:
            "📖 ${KhatmQuranDuaa.title}\n(${KhatmQuranDuaa.source})\n\n${KhatmQuranDuaa.fullText}\n\nتطبيق عِبَادُ الرَّحْمَٰن",
        subject: KhatmQuranDuaa.title,
      ),
    );
  }

  void _showImageShareSheet([String? specificDuaa]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textToRender = specificDuaa ?? KhatmQuranDuaa.fullText;
    int selectedTheme = 0; // 0: Dark Gold, 1: White Cream, 2: Deep Emerald
    bool isBusy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final themes = [
            {
              'name': 'فحمي ذهبي',
              'bg': const Color(0xFF141414),
              'border': const Color(0xFFD0A871),
              'text': const Color(0xFFF0ECE1),
              'accent': const Color(0xFFD0A871),
            },
            {
              'name': 'عاجي فاتح',
              'bg': const Color(0xFFFAF7F2),
              'border': const Color(0xFFD0A871),
              'text': const Color(0xFF2C2523),
              'accent': const Color(0xFF9E7738),
            },
            {
              'name': 'زمردي فاخر',
              'bg': const Color(0xFF0F261F),
              'border': const Color(0xFFD0A871),
              'text': const Color(0xFFE8F3EE),
              'accent': const Color(0xFFD0A871),
            },
          ];

          final current = themes[selectedTheme];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "مشاركة الدعاء كصورة",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD0A871),
                        ),
                      ),
                      // Theme selector chips
                      Row(
                        children: List.generate(themes.length, (idx) {
                          final isSel = selectedTheme == idx;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedTheme = idx),
                            child: Container(
                              margin: EdgeInsets.only(left: 6.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFFD0A871)
                                    : (isDark
                                        ? Colors.white12
                                        : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFFD0A871)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                themes[idx]['name'] as String,
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Card Preview Container
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Center(
                      child: RepaintBoundary(
                        key: _cardExportKey,
                        child: Container(
                          width: 360.w,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 22.h,
                          ),
                          decoration: BoxDecoration(
                            color: current['bg'] as Color,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: (current['border'] as Color).withValues(alpha: 0.7),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Decorative Header
                              Text(
                                "﷽",
                                style: TextStyle(
                                  fontFamily: AppConsts.quranCommon,
                                  fontSize: 22.sp,
                                  color: current['accent'] as Color,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Padding(
                                padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
                                child: Text(
                                  KhatmQuranDuaa.title,
                                  style: TextStyle(
                                    fontFamily: AppConsts.motoNastaliq,
                                    fontSize: 21.sp,
                                    color: current['accent'] as Color,
                                    height: 2.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Text(
                                KhatmQuranDuaa.source,
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 10.sp,
                                  color: (current['text'] as Color).withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 14.h),
                              Divider(
                                color: (current['accent'] as Color).withValues(alpha: 0.4),
                                thickness: 1,
                              ),
                              SizedBox(height: 12.h),

                              // Text Content
                              Text(
                                textToRender,
                                style: TextStyle(
                                  fontFamily: AppConsts.amiri,
                                  fontSize: 16.5.sp,
                                  color: current['text'] as Color,
                                  height: 2.1,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16.h),

                              // Footer App Branding
                              Divider(
                                color: (current['accent'] as Color).withValues(alpha: 0.4),
                                thickness: 1,
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_rounded,
                                    size: 14.sp,
                                    color: current['accent'] as Color,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    "تطبيق عِبَادُ الرَّحْمَٰن",
                                    style: TextStyle(
                                      fontFamily: AppConsts.expoArabic,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: current['accent'] as Color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : Colors.grey[100],
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            side: const BorderSide(color: Color(0xFFD0A871)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          icon: isBusy
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD0A871),
                                  ),
                                )
                              : const Icon(
                                  Icons.save_alt_rounded,
                                  color: Color(0xFFD0A871),
                                ),
                          label: Text(
                            "حفظ بالمعرض",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD0A871),
                            ),
                          ),
                          onPressed: isBusy
                              ? null
                              : () async {
                                  setSheetState(() => isBusy = true);
                                  try {
                                    await ShareHelper.savePageToGallery(
                                      context,
                                      _cardExportKey,
                                      'khatm_quran_duaa',
                                      quality: 3.0,
                                    );
                                  } finally {
                                    setSheetState(() => isBusy = false);
                                  }
                                },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD0A871),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          icon: isBusy
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                ),
                          label: Text(
                            "مشاركة كصورة",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: isBusy
                              ? null
                              : () async {
                                  setSheetState(() => isBusy = true);
                                  try {
                                    await ShareHelper.sharePageImage(
                                      context,
                                      _cardExportKey,
                                      'khatm_quran_duaa',
                                      quality: 3.0,
                                    );
                                  } finally {
                                    setSheetState(() => isBusy = false);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF9F9F9);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            KhatmQuranDuaa.title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              fontSize: 17.sp,
              color: const Color(0xFFD0A871),
            ),
          ),
          actions: [
            IconButton(
              tooltip: "مشاركة كصورة",
              icon: const Icon(
                FontAwesomeIcons.image,
                size: 18,
                color: Color(0xFFD0A871),
              ),
              onPressed: () => _showImageShareSheet(),
            ),
            IconButton(
              tooltip: "نسخ النص",
              icon: const Icon(
                FontAwesomeIcons.copy,
                size: 18,
                color: Color(0xFFD0A871),
              ),
              onPressed: _copyAll,
            ),
            IconButton(
              tooltip: "مشاركة كنص",
              icon: const Icon(
                FontAwesomeIcons.shareNodes,
                size: 18,
                color: Color(0xFFD0A871),
              ),
              onPressed: _shareText,
            ),
          ],
        ),
        body: Column(
          children: [
            // Subtitle source banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: const Color(0xFFD0A871),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      KhatmQuranDuaa.source,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD0A871),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Font Size Control Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.font,
                        size: 15,
                        color: Color(0xFFD0A871),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "حجم الخط",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Color(0xFFD0A871),
                        ),
                        onPressed: () {
                          if (_fontSize > 16) {
                            setState(() => _fontSize -= 2);
                          }
                        },
                      ),
                      Text(
                        "${_fontSize.toInt()}",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD0A871),
                          fontSize: 14.sp,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFFD0A871),
                        ),
                        onPressed: () {
                          if (_fontSize < 32) {
                            setState(() => _fontSize += 2);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Duaa List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                itemCount: KhatmQuranDuaa.sections.length,
                itemBuilder: (context, index) {
                  final sectionText = KhatmQuranDuaa.sections[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28.w,
                              height: 28.w,
                              margin: EdgeInsets.only(top: 4.h, left: 12.w),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFD0A871,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD0A871),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD0A871),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                sectionText,
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  fontFamily: AppConsts.amiri,
                                  fontSize: _fontSize.sp,
                                  height: 1.9,
                                  color: isDark
                                      ? const Color(0xFFECECEC)
                                      : const Color(0xFF1E1E1E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                FontAwesomeIcons.copy,
                                size: 14,
                                color: Colors.grey,
                              ),
                              tooltip: "نسخ هذا الدعاء",
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: sectionText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "تم نسخ الدعاء",
                                      style: TextStyle(fontFamily: AppConsts.cairo),
                                      textAlign: TextAlign.center,
                                    ),
                                    backgroundColor: Color(0xFFD0A871),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                FontAwesomeIcons.image,
                                size: 14,
                                color: Color(0xFFD0A871),
                              ),
                              tooltip: "مشاركة هذا الدعاء كصورة",
                              onPressed: () => _showImageShareSheet(sectionText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
