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

const List<String> fastingIntentions = [
  'الدخول من باب الريان',
  'الإخلاص وعمل السر',
  'الثبات على طاعة قدر المستطاع',
  'تحصيل التقوى',
  'البعد عن النار',
  'صيام الإثنين والخميس سنة عن رسول الله ﷺ وتعرض فيها الأعمال',
  'صيام الأيام البيض سنة عن رسول الله ﷺ ويعدل صيام الدهر',
  'الصوم يشفع للعبد',
  'طلب العفة ووقاية من الشهوة',
  'التقرب إلى منزلة حب الله',
  'اتباع سنة النبي ﷺ للنجاة من فتن الدنيا',
  'حسن الخاتمة ودخول الجنة',
  'الفرح عند لقاء الله',
  'الصيام ستر من النار',
  'رضا الله عز وجل لخلوف فم الصائم',
  'التقرب بأفضل الأعمال إلى الله',
  'تكفير الذنوب',
  'مجاهدة النفس لنيل الهداية',
  'إدراك بركة السحور',
  'إدراك الخيرية في تعجيل الفطر',
  'تزكية النفس وترويضها على الصبر',
  'شكر نعمة الصحة بالجوارح',
  'أن نكون من السبعة الذين يظلهم الله يوم القيامة',
  'اغتنام العمر ووقت الشباب في عبادة الله',
  'نيل المغفرة والأجر العظيم',
  'الصائم يبيع نفسه لله مقابل الجنة',
  'الفوز بدعوة مستجابة',
  'اتباع سنة النبي ﷺ في مخالفة الهوى والعادة',
  'الصوم مدرسة تربوية تربط بين حسن الخلق والتقوى وضبط النفس',
];

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
  bool _includeIntentions = false;
  bool _isStoryMode = true;

  final List<Color> _bgColors = [
    const Color(0xFFFCF9F2), // Warm Paper
    const Color(0xFF121212), // Night Black
    const Color(0xFF1A1F2C), // Deep Navy
    const Color(0xFF1C2826), // Dark Emerald
    Colors.white, // Pure White
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

      _currentHijri = HijriCalendar()
        ..hYear = nextYear
        ..hMonth = nextMonth
        ..hDay = 1;
      HijriCalendar.setLocal('ar');

      _loadFastingDays();
      _selectedForShare.clear();
    });
  }

  Future<void> _showQualityPicker(Function(double) onSelected) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);
    double selectedQuality = 1.0; // الافتراضي 1080p مناسب تماماً للواتساب

    final qualities = [
      {
        'title': 'قياسية (1080p Full HD)',
        'subtitle': 'مطابقة 100% لمقاس ستوري الواتساب وتمنع البكسلة (1080×1920)',
        'value': 1.0,
        'badge': 'مثالية للواتس 📱',
      },
      {
        'title': 'عالية (QHD)',
        'subtitle': 'دقة ممتازة وسريعة في الحفظ والمشاركة (1620×2880)',
        'value': 1.5,
        'badge': 'سريعة ومتوازنة ⚡',
      },
      {
        'title': 'فائقة (4K Ultra HD)',
        'subtitle': 'أعلى نقاء ووضوح فائق للشاشات الكبيرة (2160×3840)',
        'value': 2.0,
        'badge': 'أفضل نقاء 🌟',
      },
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_filter_rounded, color: gold, size: 22.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'اختر دقة حفظ الصورة',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: gold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: qualities.map((q) {
                final double val = q['value'] as double;
                final bool isSelected = selectedQuality == val;
                return InkWell(
                  onTap: () => setDlgState(() => selectedQuality = val),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? gold.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected ? gold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? gold : Colors.grey,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      q['title'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.sp,
                                        color: isSelected
                                            ? gold
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? gold.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      q['badge'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? gold : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                q['subtitle'] as String,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      side: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.4),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      onSelected(selectedQuality);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'متابعة',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImage() async {
    if (_selectedForShare.isEmpty) {
      setState(() {
        _selectedForShare.addAll(_fastingDays);
      });
      ShareHelper.showTopNotification(
        context,
        'تم تحديد جميع أيام صيام هذا الشهر تلقائياً للمشاركة',
      );
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
          ShareHelper.showTopNotification(
            context,
            'حدث خطأ أثناء إنشاء الصورة: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  Future<void> _saveImage() async {
    if (_selectedForShare.isEmpty) {
      setState(() {
        _selectedForShare.addAll(_fastingDays);
      });
      ShareHelper.showTopNotification(
        context,
        'تم تحديد جميع أيام صيام هذا الشهر تلقائياً للحفظ',
      );
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
          ShareHelper.showTopNotification(
            context,
            'تم حفظ الصورة في المعرض بنجاح ✓',
          );
        }
      } catch (e) {
        if (mounted) {
          ShareHelper.showTopNotification(
            context,
            'حدث خطأ أثناء الحفظ: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  void _showIntentionsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: gold,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'نوايا صيام التطوع (29 نية)',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: fastingIntentions.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: gold,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            fastingIntentions[index],
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'إغلاق',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomizationSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.tune_rounded, color: gold, size: 22.sp),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'تخصيص تصميم صورة الصيام',
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 1. Image Aspect Ratio / Mode
                  Text(
                    '📐 مقاس وشكل الصورة',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'ستوري واتساب (9:16)',
                          subtitle: 'شاشة كاملة للقصص والحالات',
                          icon: Icons.stay_current_portrait_rounded,
                          isSelected: _isStoryMode,
                          isDark: isDark,
                          gold: gold,
                          onTap: () {
                            setState(() => _isStoryMode = true);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'بطاقة مربعة / بوست',
                          subtitle: 'مناسبة للمنشورات والمجموعات',
                          icon: Icons.aspect_ratio_rounded,
                          isSelected: !_isStoryMode,
                          isDark: isDark,
                          gold: gold,
                          onTap: () {
                            setState(() => _isStoryMode = false);
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18.h),

                  // 2. Arrangement Layout
                  Text(
                    '🔲 طريقة ترتيب بطاقات الأيام',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'قائمة طولية',
                          subtitle: 'بطاقات متتالية رأسياً',
                          icon: Icons.view_agenda_rounded,
                          isSelected: _isVerticalShareLayout,
                          isDark: isDark,
                          gold: gold,
                          onTap: () {
                            setState(() => _isVerticalShareLayout = true);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'شبكة متجاورة',
                          subtitle: 'أيام متقابلة في صفين',
                          icon: Icons.grid_view_rounded,
                          isSelected: !_isVerticalShareLayout,
                          isDark: isDark,
                          gold: gold,
                          onTap: () {
                            setState(() => _isVerticalShareLayout = false);
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18.h),

                  // 3. Background Color
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🎨 لون خلفية الصورة',
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pickCustomColor();
                        },
                        icon: const Icon(Icons.colorize_rounded, size: 16),
                        label: const Text(
                          'لون مخصص',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 52.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._bgColors.map((color) {
                          final isSelected = _shareBgColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _shareBgColor = color);
                              setSheetState(() {});
                            },
                            child: Container(
                              width: 44.w,
                              height: 44.w,
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? gold
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: isSelected ? 3.5.w : 1.w,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: gold.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20.sp,
                                      color: color.computeLuminance() < 0.5
                                          ? Colors.white
                                          : Colors.black87,
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  SizedBox(height: 18.h),

                  // 4. Intentions inclusion
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _includeIntentions
                          ? gold.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: _includeIntentions ? gold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: gold, size: 22.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إرفاق نوايا صيام التطوع',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _includeIntentions ? gold : null,
                                ),
                              ),
                              Text(
                                'إضافة 29 نية مباركة أسفل الصورة',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _includeIntentions,
                          activeThumbColor: gold,
                          activeTrackColor: gold.withValues(alpha: 0.5),
                          onChanged: (val) {
                            setState(() => _includeIntentions = val);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'تم الاعتماد ✓',
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color gold,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withValues(alpha: 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? gold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? gold : Colors.grey,
                  size: 18.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? gold
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.sp,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
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
            icon: const Icon(Icons.tune_rounded, color: Color(0xFFD0A871)),
            tooltip: 'تخصيص التصميم والألوان',
            onPressed: _showCustomizationSheet,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomExportBar(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMonthSelector(primary),
              _buildTopControlBar(isDark),
              Expanded(
                child: _fastingDays.isEmpty
                    ? const Center(
                        child: Text("لا توجد أيام صيام محددة لهذا الشهر"),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
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
                includeIntentions: _includeIntentions,
                isStoryMode: _isStoryMode,
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

  Widget _buildTopControlBar(bool isDark) {
    const gold = Color(0xFFD0A871);
    final allSelected =
        _fastingDays.isNotEmpty && _selectedForShare.length == _fastingDays.length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Select all / Deselect all
          InkWell(
            onTap: () {
              setState(() {
                if (allSelected) {
                  _selectedForShare.clear();
                } else {
                  _selectedForShare.addAll(_fastingDays);
                }
              });
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Row(
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box_rounded
                        : (_selectedForShare.isNotEmpty
                            ? Icons.indeterminate_check_box_rounded
                            : Icons.check_box_outline_blank_rounded),
                    color: gold,
                    size: 20.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    allSelected
                        ? 'إلغاء الكل'
                        : (_selectedForShare.isEmpty
                            ? 'تحديد الكل'
                            : 'تحديد (${_selectedForShare.length})'),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Intentions button
          InkWell(
            onTap: _showIntentionsDialog,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite_outline_rounded, size: 15.sp, color: gold),
                  SizedBox(width: 4.w),
                  Text(
                    'نوايا الصيام',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Customization button
          InkWell(
            onTap: _showCustomizationSheet,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 15.sp, color: gold),
                  SizedBox(width: 4.w),
                  Text(
                    'تخصيص التصميم 🎨',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomExportBar(bool isDark) {
    const gold = Color(0xFFD0A871);
    final count = _selectedForShare.length;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Customize button (quick access)
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: gold.withValues(alpha: 0.15),
                foregroundColor: gold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.all(12.w),
              ),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'تخصيص شكل ولون الصورة',
              onPressed: _showCustomizationSheet,
            ),
            SizedBox(width: 10.w),
            // Save to gallery button
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: gold,
                  side: const BorderSide(color: gold, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  'حفظ بالمعرض',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _saveImage,
              ),
            ),
            SizedBox(width: 10.w),
            // Share image button
            Expanded(
              flex: 5,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  count > 0 ? 'مشاركة ($count) 📤' : 'مشاركة الصورة 📤',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _shareImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(Color primary) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.1)),
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
                    color: isPast
                        ? Colors.grey.withValues(alpha: 0.1)
                        : primary.withValues(alpha: 0.1),
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
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
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


  void _pickCustomColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'اختر لوناً مخصصاً',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
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
  final bool includeIntentions;
  final bool isStoryMode;

  const _FastingShareDesign({
    required this.selectedDays,
    required this.hijriMonthName,
    required this.primaryColor,
    required this.backgroundColor,
    this.isVerticalLayout = false,
    this.includeIntentions = false,
    this.isStoryMode = true,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 1080;
    final isDarkBg = backgroundColor.computeLuminance() < 0.5;
    const gold = Color(0xFFD0A871);

    final textColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.95)
        : const Color(0xFF3E2723);
    final cardBg = isDarkBg ? const Color(0xFF1E1E1E) : Colors.white;
    final cardTitleColor = isDarkBg
        ? const Color(0xFFFFF8E7)
        : const Color(0xFF3E2723);
    final cardDateColor = isDarkBg ? Colors.white70 : Colors.black54;
    final hadithBg = gold.withValues(alpha: isDarkBg ? 0.14 : 0.08);
    final hadithTextColor = isDarkBg
        ? const Color(0xFFFFF8E7)
        : const Color(0xFF5D4037);

    return Container(
      width: width,
      constraints: isStoryMode
          ? const BoxConstraints(minWidth: width, minHeight: 1920)
          : const BoxConstraints(minWidth: width),
      decoration: BoxDecoration(color: backgroundColor),
      child: Stack(
        children: [
          // Outer decorative border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                border: Border.all(
                  color: gold.withValues(alpha: isDarkBg ? 0.45 : 0.35),
                  width: 3.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Inner decorative border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(56),
              decoration: BoxDecoration(
                border: Border.all(
                  color: gold.withValues(alpha: isDarkBg ? 0.8 : 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 80,
              vertical: isStoryMode ? 100 : 80,
            ),
            child: Column(
              mainAxisAlignment: isStoryMode
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              mainAxisSize: isStoryMode ? MainAxisSize.max : MainAxisSize.min,
              children: [
                // Top Header Section
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 85,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(width: 20),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            "عباد الرحمن",
                            style: TextStyle(
                              fontFamily: AppConsts.motoNastaliq,
                              fontSize: 54,
                              fontWeight: FontWeight.normal,
                              color: gold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        "تذكير بصيام",
                        style: TextStyle(
                          fontFamily: AppConsts.motoNastaliq,
                          fontSize: 42,
                          color: textColor,
                          fontWeight: FontWeight.normal,
                          height: 2.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        hijriMonthName,
                        style: const TextStyle(
                          fontFamily: AppConsts.motoNastaliq,
                          fontSize: 72,
                          fontWeight: FontWeight.normal,
                          color: gold,
                          height: 2.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(
                      color: gold,
                      thickness: 2.5,
                      indent: 140,
                      endIndent: 140,
                    ),
                  ],
                ),

                // Middle Fasting Days Section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: isVerticalLayout
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: selectedDays
                              .map(
                                (day) => Padding(
                                  padding: const EdgeInsets.only(bottom: 22),
                                  child: _buildDayItem(
                                    day,
                                    isFullWidth: true,
                                    cardBg: cardBg,
                                    titleColor: cardTitleColor,
                                    dateColor: cardDateColor,
                                    isDarkBg: isDarkBg,
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      : Wrap(
                          spacing: 28,
                          runSpacing: 28,
                          alignment: WrapAlignment.center,
                          children: selectedDays
                              .map(
                                (day) => _buildDayItem(
                                  day,
                                  isFullWidth: false,
                                  cardBg: cardBg,
                                  titleColor: cardTitleColor,
                                  dateColor: cardDateColor,
                                  isDarkBg: isDarkBg,
                                ),
                              )
                              .toList(),
                        ),
                ),

                // Optional Intentions Section
                if (includeIntentions) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkBg
                              ? Colors.black.withValues(alpha: 0.5)
                              : gold.withValues(alpha: 0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: gold.withValues(alpha: isDarkBg ? 0.4 : 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(height: 2, width: 50, color: gold),
                            const SizedBox(width: 16),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 6),
                              child: Text(
                                "نوايا صيام التطوع",
                                style: TextStyle(
                                  fontFamily: AppConsts.motoNastaliq,
                                  fontSize: 36,
                                  fontWeight: FontWeight.normal,
                                  color: isDarkBg
                                      ? gold
                                      : const Color(0xFF5D4037),
                                  height: 2.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(height: 2, width: 50, color: gold),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Right column (items 1 to 15)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(15, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${index + 1}. ',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: gold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            fastingIntentions[index],
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkBg
                                                  ? Colors.white.withValues(
                                                      alpha: 0.9,
                                                    )
                                                  : const Color(0xFF3E2723),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Left column (items 16 to 29)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(14, (i) {
                                  final index = i + 15;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${index + 1}. ',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: gold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            fastingIntentions[index],
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkBg
                                                  ? Colors.white.withValues(
                                                      alpha: 0.9,
                                                    )
                                                  : const Color(0xFF3E2723),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Bottom Hadith Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 26,
                  ),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hadithBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: gold.withValues(alpha: isDarkBg ? 0.35 : 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    "«مَنْ صَامَ يَوْمًا فِي سَبِيلِ اللَّهِ بَعَّدَ اللَّهُ وَجْهَهُ عَنْ النَّارِ سَبْعِينَ خَرِيفًا»",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppConsts.amiri,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: hadithTextColor,
                      height: 1.6,
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

  Widget _buildDayItem(
    FastingDay day, {
    required bool isFullWidth,
    required Color cardBg,
    required Color titleColor,
    required Color dateColor,
    required bool isDarkBg,
  }) {
    const gold = Color(0xFFD0A871);
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'ar');

    return Container(
      width: isFullWidth ? 880 : 410,
      height: isFullWidth ? null : 250,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkBg
                ? Colors.black.withValues(alpha: 0.45)
                : gold.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: gold.withValues(alpha: isDarkBg ? 0.35 : 0.2),
          width: 1.5,
        ),
      ),
      child: isFullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          day.title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 34,
                            fontWeight: FontWeight.normal,
                            color: titleColor,
                            height: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateFormat.format(day.date),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          color: dateColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: isDarkBg ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: gold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      "${day.hijriDate.hDay} $hijriMonthName",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppConsts.motoNastaliq,
                        fontSize: 24,
                        color: gold,
                        fontWeight: FontWeight.normal,
                        height: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    day.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppConsts.motoNastaliq,
                      fontSize: 28,
                      fontWeight: FontWeight.normal,
                      color: titleColor,
                      height: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: isDarkBg ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: gold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      "${day.hijriDate.hDay} $hijriMonthName",
                      style: const TextStyle(
                        fontFamily: AppConsts.motoNastaliq,
                        fontSize: 20,
                        color: gold,
                        fontWeight: FontWeight.normal,
                        height: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dateFormat.format(day.date),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    color: dateColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
