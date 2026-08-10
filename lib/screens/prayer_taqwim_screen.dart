import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/prayer_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/constants/daily_wisdoms.dart';
import '../widgets/app_skeleton.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class PrayerTaqwimScreen extends StatefulWidget {
  const PrayerTaqwimScreen({super.key});

  @override
  State<PrayerTaqwimScreen> createState() => _PrayerTaqwimScreenState();
}

class _PrayerTaqwimScreenState extends State<PrayerTaqwimScreen> {
  late PageController _pageController;
  final ScreenshotController _screenshotController = ScreenshotController();
  final DateTime _today = DateTime.now();
  final int _initialPage = 5000;
  int _currentPage = 5000;
  bool _isSaving = false;
  Color? _customBgColor;

  final List<Color> _presetColors = [
    const Color(0xFF161B22), // Default Dark
    Colors.white,
    const Color(0xFFFCF9F2), // Warm Paper
    const Color(0xFFE8F5E9), // Soft Green
    const Color(0xFFE3F2FD), // Soft Blue
    const Color(0xFFFFF3E0), // Soft Orange
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _loadBgColor();
  }

  Future<void> _loadBgColor() async {
    final prefs = CacheHelper.prefs;
    final colorVal = prefs.getInt('taqwim_bg_color');
    if (colorVal != null) {
      setState(() => _customBgColor = Color(colorVal));
    }
  }

  Future<void> _saveBgColor(Color color) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt('taqwim_bg_color', color.toARGB32());
    setState(() => _customBgColor = color);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getDateForPage(int page) {
    return _today.add(Duration(days: page - _initialPage));
  }

  void _changePage(int delta) {
    _pageController.animateToPage(
      _currentPage + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showTopNotification(BuildContext context, String message, {bool isError = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  Future<void> _showQualityPicker(Function(double) onSelected) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);
    double quality = 5.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: const Text(
            'اختر جودة الصورة',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold, color: gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQualityOption('عالية', 5.0, quality == 5.0, (v) => setDlgState(() => quality = v)),
                  const SizedBox(width: 8),
                  _buildQualityOption('متوسطة', 3.0, quality == 3.0, (v) => setDlgState(() => quality = v)),
                  const SizedBox(width: 8),
                  _buildQualityOption('منخفضة', 1.0, quality == 1.0, (v) => setDlgState(() => quality = v)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    onSelected(quality);
                    Navigator.pop(ctx);
                  },
                  child: const Text('تأكيد', style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityOption(String label, double value, bool isSelected, Function(double) onTap) {
    const gold = Color(0xFFD0A871);
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : gold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImage() async {
    await _showQualityPicker((quality) async {
      setState(() => _isSaving = true);
      try {
        final Uint8List? imageBytes = await _screenshotController.capture(
          pixelRatio: quality, // High resolution for sharing
        );
        if (imageBytes != null) {
          final directory = await getTemporaryDirectory();
          final imagePath =
              '${directory.path}/taqwim_${DateTime.now().millisecondsSinceEpoch}.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(imageBytes);

          await Gal.putImage(imagePath);

          if (mounted) {
            _showTopNotification(context, 'تم حفظ النتيجة في المعرض بنجاح');
          }
        }
      } catch (e) {
        if (mounted) {
          _showTopNotification(context, 'خطأ أثناء الحفظ: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "النتيجة اليومية",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: goldColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: goldColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showColorPicker,
            tooltip: 'تغيير لون الخلفية',
          ),
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: AppSkeleton(width: 24.w, height: 24.w, borderRadius: 12),
            )
          else
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _saveAsImage,
              tooltip: 'حفظ كصورة',
            ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Bar
          _buildNavBar(isDark, goldColor),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, page) {
                final pageContent = _TaqwimPage(
                  date: _getDateForPage(page),
                  forcedBgColor: _customBgColor,
                );
                // Only wrap the active page with Screenshot to avoid Duplicate GlobalKey error
                // when PageView pre-builds adjacent pages.
                if (page == _currentPage) {
                  return Center(
                    child: Screenshot(
                      controller: _screenshotController,
                      child: pageContent,
                    ),
                  );
                }
                return Center(child: pageContent);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20.w),
        height: 220.h,
        child: Column(
          children: [
            Text(
              "اختر لون خلفية النتيجة",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 20.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._presetColors.map(
                    (color) => GestureDetector(
                      onTap: () {
                        _saveBgColor(color);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        margin: EdgeInsets.symmetric(horizontal: 5.w),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _customBgColor == color
                                ? const Color(0xFFD0A871)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: _customBgColor == color ? 3.w : 1.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Custom Color Picker Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickCustomColor();
                    },
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      margin: EdgeInsets.symmetric(horizontal: 5.w),
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1.w,
                        ),
                      ),
                      child: Icon(
                        Icons.colorize,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCustomColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'اختر لوناً مخصصاً',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 18.sp),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _customBgColor ?? const Color(0xFF161B22),
            onColorChanged: (color) {
              setState(() => _customBgColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_customBgColor != null) _saveBgColor(_customBgColor!);
              Navigator.pop(ctx);
            },
            child: Text(
              'تم',
              style: TextStyle(
                color: const Color(0xFFD0A871),
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(bool isDark, Color goldColor) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.3), width: 1.0.w),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: goldColor, size: 20.sp),
            onPressed: () => _changePage(-1),
          ),
          Text(
            "تغيير اليوم",
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              color: goldColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: goldColor, size: 20.sp),
            onPressed: () => _changePage(1),
          ),
        ],
      ),
    );
  }
}

class _TaqwimPage extends StatelessWidget {
  final DateTime date;
  final Color? forcedBgColor;

  const _TaqwimPage({required this.date, this.forcedBgColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = date.add(Duration(days: hijriOffset));
    final hijri = HijriCalendar.fromDate(adjustedDate);

    final dayName = DateFormat('EEEE', 'ar').format(date);
    final gregDay = date.day.toString();
    final gregMonthYear = DateFormat('MMMM yyyy', 'ar').format(date);

    final isFriday = date.weekday == DateTime.friday;
    const goldColor = Color(0xFFD0A871);

    // Use forced color if provided, otherwise theme-based default
    final cardBg =
        forcedBgColor ?? (isDark ? const Color(0xFF161B22) : Colors.white);

    // Smart text color adjustment based on background luminance
    final bool isLightBg = cardBg.computeLuminance() > 0.5;
    final textColor = isLightBg ? Colors.black87 : Colors.white;
    final subTextColor = isLightBg ? Colors.black54 : Colors.white70;

    return AspectRatio(
      aspectRatio: 1 / 1.6, // Fixed professional ratio
      child: Container(
        width: 320.w,
        margin: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(25.r),
          border: Border.all(color: goldColor.withValues(alpha: 0.5), width: 2.w),
          boxShadow: [
            BoxShadow(
              color: isLightBg
                  ? Colors.black.withAlpha(20)
                  : goldColor.withValues(alpha: 0.2),
              blurRadius: 20.r,
              spreadRadius: 2.r,
            ),
          ],
        ),
        child: Column(
          children: [
            // Elegant Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    goldColor.withValues(alpha: 0.8),
                    const Color(0xFF8B6E3F),
                    goldColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(23.r),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    "عِبَادُ الرَّحْمَٰن",
                    style: TextStyle(
                      fontFamily: AppConsts.motoNastaliq,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dayName,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
                  child: Column(
                    children: [
                      // Dates Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDateSide(
                            hijri.hDay.toString(),
                            hijri.longMonthName,
                            "${hijri.hYear} هـ",
                            isFriday ? Colors.redAccent : goldColor,
                            textColor,
                          ),
                          Container(
                            height: 40.h,
                            width: 1.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  goldColor.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          _buildDateSide(
                            gregDay,
                            gregMonthYear,
                            "",
                            isLightBg ? Colors.black87 : Colors.white,
                            textColor,
                          ),
                        ],
                      ),

                      SizedBox(height: 5.h),
                      Divider(
                        color: goldColor,
                        thickness: 0.5.h,
                        indent: 40.w,
                        endIndent: 40.w,
                      ),
                      SizedBox(height: 5.h),

                      // Prayer Times List
                      FutureBuilder<List<ExtendedPrayer>>(
                        future: PrayerService().getExtendedPrayers(date: date),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Column(
                              children: List.generate(
                                6,
                                (index) => AppSkeleton.prayerRow(),
                              ),
                            );
                          }

                          final prayers = snapshot.data!
                              .where(
                                (p) =>
                                    p.id == 'fajr' ||
                                    p.id == 'sunrise' ||
                                    p.id == 'dhuhr' ||
                                    p.id == 'asr' ||
                                    p.id == 'maghrib' ||
                                    p.id == 'isha',
                              )
                              .toList();

                          return Column(
                            children: prayers
                                .map(
                                  (p) => _buildLuxuriousRow(
                                    p,
                                    isLightBg,
                                    goldColor,
                                    textColor,
                                    subTextColor,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      // Wisdom Section
                      _WisdomSection(
                        date: date,
                        isLightBg: isLightBg,
                        goldColor: goldColor,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSide(
    String day,
    String month,
    String year,
    Color mainColor,
    Color textColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 38.sp,
              fontWeight: FontWeight.bold,
              color: mainColor,
              height: 1.1,
              shadows: [
                Shadow(color: mainColor.withValues(alpha: 0.3), blurRadius: 10.r),
              ],
            ),
          ),
          Text(
            month,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: mainColor.withValues(alpha: 0.8),
            ),
          ),
          if (year.isNotEmpty)
            Text(
              year,
              style: TextStyle(
                fontSize: 11.sp,
                color: mainColor.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLuxuriousRow(
    ExtendedPrayer p,
    bool isLightBg,
    Color goldColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: isLightBg ? 0.03 : 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: goldColor.withValues(alpha: isLightBg ? 0.2 : 0.1),
          width: 1.0.w,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            p.name,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 15.sp,
              color: subTextColor,
            ),
          ),
          Text(
            PrayerService().formatTime(p.time),
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: goldColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WisdomSection extends StatelessWidget {
  final DateTime date;
  final bool isLightBg;
  final Color goldColor;
  final Color textColor;

  const _WisdomSection({
    required this.date,
    required this.isLightBg,
    required this.goldColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isFriday = date.weekday == DateTime.friday;

    String wisdom;
    if (isFriday) {
      wisdom = fridayWisdoms[date.day % fridayWisdoms.length];
    } else {
      wisdom = dailyWisdoms[date.day % dailyWisdoms.length];
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: isLightBg ? 0.02 : 0.03),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: goldColor.withValues(alpha: isLightBg ? 0.15 : 0.2),
          width: 1.0.w,
        ),
        image: DecorationImage(
          image: const AssetImage('assets/images/mosque_bottom.webp'),
          opacity: isLightBg ? 0.03 : 0.05,
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote_rounded, color: goldColor, size: 20.sp),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              wisdom,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 12.sp,
                color: isLightBg
                    ? Colors.black87
                    : Colors.white.withValues(alpha: 0.9),
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
