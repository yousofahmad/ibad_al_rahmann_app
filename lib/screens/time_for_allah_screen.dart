import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';

class TimeForAllahScreen extends StatefulWidget {
  const TimeForAllahScreen({super.key});

  @override
  State<TimeForAllahScreen> createState() => _TimeForAllahScreenState();
}

class _TimeForAllahScreenState extends State<TimeForAllahScreen> {
  final TextEditingController _dhikrController = TextEditingController();
  int _selectedMinutes = 10;
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isActive = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _dhikrController.text = "سبحان الله وبحمده";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _dhikrController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_dhikrController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("يرجى إدخال الذكر أولاً")));
      return;
    }

    setState(() {
      _secondsRemaining = _selectedMinutes * 60;
      _isActive = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _stopTimer();
        _onTimerFinished();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
    });
  }

  void _onTimerFinished() async {
    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 1000);
    }

    // Play sound (optional, assuming nafis.mp3 or similar exists for notification)
    try {
      await _audioPlayer.setAsset('assets/audio/nafis.mp3');
      _audioPlayer.play();
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text(
            "تقبل الله منك",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Color(0xFFD0A871),
            ),
          ),
          content: const Text(
            "انتهى الوقت المحدد للذكر. جعلها الله في ميزان حسناتك.",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppConsts.expoArabic),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "أمين",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Color(0xFFD0A871),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "وقت لله",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            // Timer Display
            Container(
              height: 250.h,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200.w,
                    height: 200.w,
                    child: _isActive 
                      ? CircularProgressIndicator(
                        value: _secondsRemaining / (_selectedMinutes * 60),
                        strokeWidth: 8.w,
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          primaryColor,
                        ),
                      )
                      : AppSkeleton(width: 200.w, height: 200.w, borderRadius: 100.r),
                  ),
                  Text(
                    _isActive
                        ? _formatTime(_secondsRemaining)
                        : "$_selectedMinutes:00",
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            if (!_isActive) ...[
              // Time Selector
              Text(
                "حدد الوقت (بالدقائق)",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Colors.grey,
                  fontSize: 14.sp,
                ),
              ),
              Slider(
                value: _selectedMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                activeColor: primaryColor,
                label: "$_selectedMinutes دقيقة",
                onChanged: (val) =>
                    setState(() => _selectedMinutes = val.toInt()),
              ),
              SizedBox(height: 20.h),
              // Dhikr Input
              TextField(
                controller: _dhikrController,
                textAlign: TextAlign.center,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "أدخل الذكر الذي تريد تكراره",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    borderSide: const BorderSide(color: primaryColor),
                  ),
                ),
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40.h),
              // Start Button
              SizedBox(
                width: double.infinity,
                height: 55.h,
                child: ElevatedButton(
                  onPressed: _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                  child: Text(
                    "ابدأ الآن",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Active Mode Display
              SizedBox(height: 20.h),
              Text(
                "أشغل وقتك بذكر الله",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: primaryColor,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1.0.w,
                  ),
                ),
                child: Text(
                  _dhikrController.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 50.h),
              // Cancel Button
              TextButton.icon(
                onPressed: _stopTimer,
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.redAccent,
                  size: 24.sp,
                ),
                label: Text(
                  "إنهاء الجلسة",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
