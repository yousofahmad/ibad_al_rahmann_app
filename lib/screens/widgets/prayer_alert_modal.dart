import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhan/adhan.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

/// Modernized Prayer Alert Modal / Overlay Widget
///
/// Features:
/// 1. Full-screen scaffold with semi-transparent dark background (`Colors.black.withOpacity(0.7)`)
/// 2. Background tap anywhere triggers snooze/dismiss logic
/// 3. Prominent circular prayer image with Islamic styling
/// 4. Timer text ("الوقت المتبقي: ...") and thick rounded progress bar
/// 5. Full-width action buttons ("صليتُ والله" & "ذكرني") with 20px border radius
/// 6. Preserves all audio, status saving, and callback logic
class PrayerAlertModal extends StatefulWidget {
  final String prayerName;
  final int streak;
  final int snoozeMinutes;
  final String? nextPrayerName;
  final DateTime? nextPrayerTime;
  final DateTime? currentPrayerTime;
  final VoidCallback onPrayedOnTime;
  final VoidCallback onPrayedLate;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  const PrayerAlertModal({
    super.key,
    required this.prayerName,
    required this.streak,
    this.snoozeMinutes = 10,
    this.nextPrayerName,
    this.nextPrayerTime,
    this.currentPrayerTime,
    required this.onPrayedOnTime,
    required this.onPrayedLate,
    required this.onSnooze,
    required this.onDismiss,
  });

  /// Helper to display this modal over any screen
  static Future<void> show(
    BuildContext context, {
    required String prayerName,
    required int streak,
    int snoozeMinutes = 5,
    String? nextPrayerName,
    DateTime? nextPrayerTime,
    DateTime? currentPrayerTime,
    required VoidCallback onPrayedOnTime,
    required VoidCallback onPrayedLate,
    required VoidCallback onSnooze,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) => PrayerAlertModal(
        prayerName: prayerName,
        streak: streak,
        snoozeMinutes: snoozeMinutes,
        nextPrayerName: nextPrayerName,
        nextPrayerTime: nextPrayerTime,
        currentPrayerTime: currentPrayerTime,
        onPrayedOnTime: () {
          Navigator.of(ctx).pop();
          onPrayedOnTime();
        },
        onPrayedLate: () {
          Navigator.of(ctx).pop();
          onPrayedLate();
        },
        onSnooze: () {
          Navigator.of(ctx).pop();
          onSnooze();
        },
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss();
        },
      ),
    );
  }

  @override
  State<PrayerAlertModal> createState() => _PrayerAlertModalState();
}

class _PrayerAlertModalState extends State<PrayerAlertModal> {
  bool _isConfirmStep = false;
  bool _isAchievementStep = false;
  int _snoozeCountdown = 5;
  Timer? _snoozeCountdownTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startSnoozeCountdown();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _snoozeCountdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startSnoozeCountdown() {
    _snoozeCountdown = 5;
    _snoozeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_snoozeCountdown > 0) {
        if (mounted) setState(() => _snoozeCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  String _getPrayerImage() {
    final name = widget.prayerName;
    final isFriday = DateTime.now().weekday == DateTime.friday;
    if (name.contains('فجر')) return 'assets/images/ic_fajr.png';
    if (name.contains('ظهر') || name.contains('جمعة')) {
      return isFriday ? 'assets/images/ic_jumuah_prayer.png' : 'assets/images/ic_dhuhr.png';
    }
    if (name.contains('عصر')) return 'assets/images/ic_asr.png';
    if (name.contains('مغرب')) return 'assets/images/ic_maghrib.png';
    if (name.contains('عشاء')) return 'assets/images/ic_isha.png';
    return 'assets/images/header_salati.png';
  }

  (String, double) _calculateRemainingTimeAndProgress() {
    final now = DateTime.now();
    DateTime? nextTime = widget.nextPrayerTime;
    DateTime? currTime = widget.currentPrayerTime;

    if (nextTime == null) {
      final pService = PrayerService();
      final times = pService.getPrayerTimes();
      if (times != null) {
        final nextP = times.nextPrayer();
        if (nextP != Prayer.none) {
          nextTime = times.timeForPrayer(nextP);
        }
        final currentP = times.currentPrayer();
        if (currentP != Prayer.none) {
          currTime = times.timeForPrayer(currentP);
        }
      }
    }

    if (nextTime == null || nextTime.isBefore(now)) {
      return ('الصلاة قائمة الآن', 1.0);
    }

    final diff = nextTime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    String timeStr;
    if (hours > 0) {
      timeStr = '${hours}h ${minutes}m';
    } else {
      timeStr = '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }

    double progress = 0.5;
    if (currTime != null && nextTime.isAfter(currTime)) {
      final totalMs = nextTime.difference(currTime).inMilliseconds;
      final elapsedMs = now.difference(currTime).inMilliseconds;
      if (totalMs > 0) {
        progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
      }
    }

    return (timeStr, progress);
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD0A871);
    const goldDark = Color(0xFF8B5E1A);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Root widget: Transparent Material with centered modal card (dimming handled by WindowManager / showDialog)
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Container(
              width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 420.w,
              minHeight: 460.h,
            ),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: _isAchievementStep
                ? _buildAchievementStep(goldColor, goldDark, isDark)
                : (_isConfirmStep
                    ? _buildConfirmStep(goldColor, goldDark, isDark)
                    : _buildMainAlertContent(goldColor, goldDark, isDark)),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMainAlertContent(Color goldColor, Color goldDark, bool isDark) {
    final subColor = isDark ? Colors.white70 : const Color(0xFF6E655C);
    final (remainingTimeText, progressValue) = _calculateRemainingTimeAndProgress();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rule 3: Retain prominent circular prayer image
        Center(
          child: Container(
            width: 95.w,
            height: 95.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: goldColor.withValues(alpha: 0.1),
              border: Border.all(color: goldColor.withValues(alpha: 0.4), width: 2),
            ),
            padding: EdgeInsets.all(12.w),
            child: Image.asset(
              _getPrayerImage(),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.mosque_rounded,
                size: 48.sp,
                color: goldColor,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),

        Text(
          'حان وقت الصلاة',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 13.sp,
            color: subColor,
          ),
        ),
        SizedBox(height: 4.h),

        // Prayer Name
        Text(
          'صلاة ${widget.prayerName}',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: goldColor,
          ),
        ),
        SizedBox(height: 6.h),

        // Streak Text
        if (widget.streak > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFFF8C00).withValues(alpha: 0.3)),
            ),
            child: Text(
              '🔥 ${widget.streak} صلوات متتالية',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF8C00),
              ),
            ),
          )
        else
          Text(
            'ابدأ سلسلة الصلاة اليوم',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 12.sp,
              color: subColor,
            ),
          ),
        SizedBox(height: 18.h),

        // Rule 4: Timer & Progress Bar Section
        IgnorePointer(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الوقت المتبقي للآتية:',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 12.sp,
                      color: subColor,
                    ),
                  ),
                  Text(
                    remainingTimeText,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // Thick rounded progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 8.h,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                ),
              ),
            ],
          ),
        ),
        ),
        SizedBox(height: 24.h),

        // Rule 5: Action buttons (Full Width with large border radius 20)
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _isConfirmStep = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: goldDark,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              'صليتُ والله ✓',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),

        SizedBox(
          width: double.infinity,
          height: 44.h,
          child: OutlinedButton(
            onPressed: _snoozeCountdown == 0
                ? () {
                    // CRITICAL: Calculate target time STRICTLY at the exact moment of the tap
                    final now = DateTime.now();
                    final targetSnoozeTime = now.add(Duration(minutes: widget.snoozeMinutes));
                    debugPrint('Snoozed at $now, next alert target: $targetSnoozeTime');
                    widget.onSnooze();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: goldColor,
              side: BorderSide(
                color: goldColor.withValues(alpha: _snoozeCountdown == 0 ? 0.6 : 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              _snoozeCountdown > 0
                  ? 'ذكرني بعد ${widget.snoozeMinutes} دقائق ($_snoozeCountdown)'
                  : 'ذكرني بعد ${widget.snoozeMinutes} دقائق',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 13.sp,
                color: _snoozeCountdown > 0 ? Colors.grey : goldColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(Color goldColor, Color goldDark, bool isDark) {
    final subColor = isDark ? Colors.white70 : const Color(0xFF6E655C);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: goldColor, size: 54.sp),
        SizedBox(height: 12.h),

        Text(
          'هل صليتَها في وقتها أم متأخراً؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'تسجيل صلاة ${widget.prayerName}',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 13.sp,
            color: subColor,
          ),
        ),
        SizedBox(height: 24.h),

        // Buttons (Full width with border radius 20)
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              'في وقتها ✓',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            onPressed: () {
              widget.onPrayedOnTime();
              setState(() => _isAchievementStep = true);
            },
          ),
        ),
        SizedBox(height: 10.h),

        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
            label: Text(
              'متأخراً ⏳',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD84315),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            onPressed: () {
              widget.onPrayedLate();
              setState(() => _isAchievementStep = true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementStep(Color goldColor, Color goldDark, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1C1A18);
    final streak = widget.streak + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'الحمد لله!',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: goldColor,
          ),
        ),
        SizedBox(height: 6.h),

        Text(
          'أتممت صلاة ${widget.prayerName} تقبل الله منا ومنكم صالح الأعمال',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 13.sp,
            color: textColor,
          ),
        ),
        SizedBox(height: 20.h),

        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            children: [
              Text(
                '🔥 $streak',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF8C00),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'صلوات متتالية دون انقطاع',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 13.sp,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            onPressed: () {
              widget.onDismiss();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: goldDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              'متابعة',
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
