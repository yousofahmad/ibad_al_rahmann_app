import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/models/fasting_day.dart';
import 'package:ibad_al_rahmann/services/fasting_logic.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/image_generation_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../core/helpers/share_helper.dart';

class FastingDaysScreen extends StatefulWidget {
  const FastingDaysScreen({super.key});

  @override
  State<FastingDaysScreen> createState() => _FastingDaysScreenState();
}

class _FastingDaysScreenState extends State<FastingDaysScreen> {
  late List<FastingDay> _fastingDays;
  final Set<FastingDay> _selectedForShare = {};
  late HijriCalendar _currentHijri;
  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isCapturing = false;
  Color _shareBgColor = const Color(0xFFFCF9F2);
  bool _isVerticalShareLayout = false;

  final List<Color> _bgColors = [
    const Color(0xFFFCF9F2), // Warm Paper
    Colors.white,
    const Color(0xFFE8F5E9), // Soft Green
    const Color(0xFFE3F2FD), // Soft Blue
    const Color(0xFFFFF3E0), // Soft Orange
    const Color(0xFFF3E5F5), // Soft Purple
  ];

  @override
  void initState() {
    super.initState();
    _currentHijri = PrayerService().getAdjustedHijri();
    _loadFastingDays();
  }

  void _loadFastingDays() {
    _fastingDays = FastingLogic.getFastingDaysForMonth(
      _currentHijri.hMonth,
      _currentHijri.hYear,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      int nextMonth = _currentHijri.hMonth + delta;
      int nextYear = _currentHijri.hYear;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      } else if (nextMonth < 1) {
        nextMonth = 12;
        nextYear--;
      }

      final temp = HijriCalendar();
      final DateTime greg = temp.hijriToGregorian(nextYear, nextMonth, 1);
      _currentHijri = HijriCalendar.fromDate(greg);

      _loadFastingDays();
      _selectedForShare.clear();
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

  Future<void> _shareImage() async {
    if (_selectedForShare.isEmpty) {
      ShareHelper.showTopNotification(context, 'الرجاء اختيار يوم واحد على الأقل للمشاركة', isError: true);
      return;
    }

    await _showQualityPicker((quality) async {
      setState(() => _isCapturing = true);
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        final bytes = await ImageGenerationService.captureAsPng(
          _shareBoundaryKey,
          pixelRatio: quality,
        );
        final path = await ImageGenerationService.saveTempAndGetPath(
          bytes,
          filename: 'fasting_reminder.png',
        );

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'image/png')],
            text: 'تذكير بصيام',
          ),
        );
      } catch (e) {
        if (mounted) {
          ShareHelper.showTopNotification(context, 'حدث خطأ أثناء إنشاء الصورة: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  Future<void> _saveImage() async {
    if (_selectedForShare.isEmpty) {
      ShareHelper.showTopNotification(context, 'الرجاء اختيار يوم واحد على الأقل للحفظ', isError: true);
      return;
    }

    await _showQualityPicker((quality) async {
      setState(() => _isCapturing = true);
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        final bytes = await ImageGenerationService.captureAsPng(
          _shareBoundaryKey,
          pixelRatio: quality,
        );
        await ImageGenerationService.saveToGallery(bytes);

        if (mounted) {
          ShareHelper.showTopNotification(context, 'تم حفظ الصورة في المعرض بنجاح ✨');
        }
      } catch (e) {
        if (mounted) {
          ShareHelper.showTopNotification(context, 'حدث خطأ أثناء الحفظ: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "أيام الصيام",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isVerticalShareLayout ? Icons.grid_view : Icons.view_day),
            onPressed: () {
              setState(() => _isVerticalShareLayout = !_isVerticalShareLayout);
              ShareHelper.showTopNotification(
                context,
                _isVerticalShareLayout
                    ? 'وضع البطاقات (طولي)'
                    : 'وضع البطاقات (شبكي)',
              );
            },
            tooltip: 'تغيير شكل الترتيب',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showColorPicker,
            tooltip: 'تغيير لون الصورة',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _saveImage,
            tooltip: 'حفظ في المعرض',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareImage,
            tooltip: 'مشاركة الصورة',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMonthSelector(primary),
              Expanded(
                child: _fastingDays.isEmpty
                    ? const Center(
                        child: Text("لا توجد أيام صيام محددة لهذا الشهر"),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _fastingDays.length,
                        itemBuilder: (context, index) {
                          final day = _fastingDays[index];
                          final isSelected = _selectedForShare.contains(day);
                          return _buildFastingCard(day, isSelected);
                        },
                      ),
              ),
            ],
          ),
          
          // Hidden RepaintBoundary for high-res capture
          Positioned(
            left: -5000,
            child: RepaintBoundary(
              key: _shareBoundaryKey,
              child: _FastingShareDesign(
                selectedDays: _selectedForShare.toList(),
                hijriMonthName: _currentHijri.longMonthName,
                primaryColor: primary,
                backgroundColor: _shareBgColor,
                isVerticalLayout: _isVerticalShareLayout,
              ),
            ),
          ),

          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFD0A871)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(Color primary) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _changeMonth(1),
          ),
          Text(
            "${_currentHijri.longMonthName} ${_currentHijri.hYear} هـ",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _changeMonth(-1),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingCard(FastingDay day, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'ar');
    
    // Check if the day is in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = day.date.isBefore(today);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.r),
        side: BorderSide(
          color: isSelected ? primary : Colors.grey.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isPast 
          ? (isDark ? Colors.black26 : Colors.grey.shade100)
          : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedForShare.contains(day)) {
              _selectedForShare.remove(day);
            } else {
              _selectedForShare.add(day);
            }
          });
        },
        borderRadius: BorderRadius.circular(15.r),
        child: Opacity(
          opacity: isPast ? 0.6 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: isPast ? Colors.grey.withValues(alpha: 0.1) : primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.hijriDate.hDay.toString(),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: isPast ? Colors.grey : primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.title,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isPast ? Colors.grey : null,
                        ),
                      ),
                      Text(
                        dateFormat.format(day.date),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  activeColor: primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedForShare.add(day);
                      } else {
                        _selectedForShare.remove(day);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
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
            const Text(
              "اختر لون خلفية الصورة",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._bgColors.map(
                    (color) => GestureDetector(
                      onTap: () {
                        setState(() => _shareBgColor = color);
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
                            color: _shareBgColor == color
                                ? const Color(0xFFD0A871)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: _shareBgColor == color ? 3.w : 1.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickCustomColor();
                    },
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      margin: EdgeInsets.symmetric(horizontal: 5.w),
                      decoration: const BoxDecoration(
                        gradient: SweepGradient(
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
                      ),
                      child: const Icon(Icons.colorize, color: Colors.white, size: 20),
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
        title: const Text('اختر لوناً مخصصاً', style: TextStyle(fontFamily: 'Cairo')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _shareBgColor,
            onColorChanged: (color) {
              setState(() => _shareBgColor = color);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم', style: TextStyle(color: Color(0xFFD0A871))),
          ),
        ],
      ),
    );
  }
}

class _FastingShareDesign extends StatelessWidget {
  final List<FastingDay> selectedDays;
  final String hijriMonthName;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isVerticalLayout;

  const _FastingShareDesign({
    required this.selectedDays,
    required this.hijriMonthName,
    required this.primaryColor,
    required this.backgroundColor,
    this.isVerticalLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 1200;

    return Container(
      width: width,
      decoration: BoxDecoration(color: backgroundColor),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(50),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.4),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(75),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD0A871), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 120),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(width: 25),
                        const Text(
                          "عباد الرحمن",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD0A871),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    const Text(
                      "تذكير بصيام",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 44,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      hijriMonthName,
                      style: const TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD0A871),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(
                      color: Color(0xFFD0A871),
                      thickness: 3,
                      indent: 150,
                      endIndent: 150,
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: isVerticalLayout
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: selectedDays
                              .map((day) => Padding(
                                    padding: const EdgeInsets.only(bottom: 30),
                                    child: _buildDayItem(day, isFullWidth: true),
                                  ))
                              .toList(),
                        )
                      : Wrap(
                          spacing: 40,
                          runSpacing: 40,
                          alignment: WrapAlignment.center,
                          children: selectedDays
                              .map((day) => _buildDayItem(day, isFullWidth: false))
                              .toList(),
                        ),
                ),

                Container(
                  padding: const EdgeInsets.all(40),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Text(
                    "«مَنْ صَامَ يَوْمًا فِي سَبِيلِ اللَّهِ بَعَّدَ اللَّهُ وَجْهَهُ عَنْ النَّارِ سَبْعِينَ خَرِيفًا»",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF5D4037),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(FastingDay day, {required bool isFullWidth}) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'ar');
    return Container(
      width: isFullWidth ? 1000 : 450,
      height: isFullWidth ? null : 320, // Added fixed height for grid mode
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD0A871).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: isFullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      style: const TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dateFormat.format(day.date),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 24,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    "${day.hijriDate.hDay} $hijriMonthName",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 30,
                      color: Color(0xFFD0A871),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${day.hijriDate.hDay} $hijriMonthName",
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 28,
                      color: Color(0xFFD0A871),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  dateFormat.format(day.date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}
