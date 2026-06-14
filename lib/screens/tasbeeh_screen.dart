import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  int _counter = 0;
  int _target = 33;
  bool _isTargetMode = true; // true = محدد, false = مفتوح
  bool _vibrationEnabled = true;
  final TextEditingController _zekrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadSettings();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrationEnabled = prefs.getBool('vibrate_tasbeeh') ?? true;
    });
  }

  void _incrementCounter() {
    setState(() {
      if (_isTargetMode) {
        if (_counter < _target) {
          _counter++;
          if (_counter == _target) {
            // اهتزاز عند الوصول للهدف
            if (_vibrationEnabled) NotificationService.vibrate(duration: 500);
          }
        }
      } else {
        // الوضع المفتوح
        _counter++;
      }
      // اهتزاز قوي مع كل عدة بناء على طلب المستخدم
      if (_vibrationEnabled) NotificationService.vibrate(duration: 70);
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  void _setTarget(int target) {
    setState(() {
      _target = target;
      if (_isTargetMode) {
        _counter = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الثيم الحالي
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تعريف الألوان بناءً على الثيم
    final Color mainTextColor = isDark ? Colors.white : Colors.black87;
    final Color containerColor = isDark
        ? const Color(0xFF000000).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);
    const Color borderColor = Color(0xFFD0A871);
    final Color scaffoldBgColor = isDark
        ? Colors.black
        : const Color(0xFFF5F5F5);
    final Color appBarBgColor = isDark ? const Color(0xFF000000) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: scaffoldBgColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: appBarBgColor,
          centerTitle: true,
          toolbarHeight: 55.h,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: borderColor,
              size: 18.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'التسبيح',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: borderColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage(
                'assets/images/a7c49f562eff865f97964f9d75a85b8d.jpg',
              ),
              fit: BoxFit.cover,
              // فلتر لتغميق الصورة في الوضع الليلي فقط
              colorFilter: isDark
                  ? ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.6),
                      BlendMode.darken,
                    )
                  : null,
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 20.h),
              // خانة إضافة ذكر
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _zekrController,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: mainTextColor,
                      fontSize: 16.sp,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "أضف ذكرك هنا (اختياري)...",
                      hintStyle: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        color: mainTextColor.withValues(alpha: 0.5),
                        fontSize: 14.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // حاوية العداد
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 30.h,
                  horizontal: 20.w,
                ),
                margin: EdgeInsets.symmetric(horizontal: 30.w),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(25.r),
                  border: Border.all(color: borderColor, width: 1.5.w),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180.w,
                          height: 180.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: List.generate(12, (index) {
                              int loopTarget = _isTargetMode ? _target : 100;
                              double angle = (index * 30) * (pi / 180);
                              double radius = 75.w;
                              double progress =
                                  (_counter % loopTarget) / loopTarget;
                              if (_counter > 0 && _counter % loopTarget == 0) {
                                progress = 1.0;
                              }
                              int activeBeads = (progress * 12).floor();
                              bool isActive =
                                  index < activeBeads || (progress == 1.0);

                              return Positioned(
                                left: 90.w + radius * cos(angle) - 5.w,
                                top: 90.w + radius * sin(angle) - 5.w,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? borderColor
                                        : (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.1),
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: borderColor.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 4.r,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$_counter',
                              style: TextStyle(
                                fontSize: 48.sp,
                                fontWeight: FontWeight.bold,
                                color: borderColor,
                              ),
                            ),
                            Text(
                              _isTargetMode ? 'من $_target' : 'وضع مفتوح',
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.sp,
                                color: mainTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30.h),
              // زر التسبيح
              GestureDetector(
                onTap: _incrementCounter,
                child: Container(
                  width: 90.w,
                  height: 90.w,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: isDark ? Colors.black : Colors.white,
                    size: 40.sp,
                  ),
                ),
              ),

              const Spacer(),

              // أدوات التحكم السفلية
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 20.h,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF000000).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10.r,
                      offset: Offset(0, -2.h),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "نوع العداد:",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: mainTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                        Row(
                          children: [
                            _buildModeBtn(
                              "محدد",
                              true,
                              isDark,
                              borderColor,
                              mainTextColor,
                            ),
                            SizedBox(width: 10.w),
                            _buildModeBtn(
                              "مفتوح",
                              false,
                              isDark,
                              borderColor,
                              mainTextColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_isTargetMode) ...[
                      SizedBox(height: 15.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [33, 99, 1000].map((t) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            child: ChoiceChip(
                              label: Text('$t'),
                              selected: _target == t,
                              onSelected: (val) => _setTarget(t),
                              selectedColor: borderColor,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.r),
                                side: BorderSide.none,
                              ),
                              labelStyle: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: _target == t
                                    ? (isDark ? Colors.black : Colors.white)
                                    : mainTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    SizedBox(height: 10.h),
                    // زر التصفير
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _resetCounter,
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.redAccent,
                          size: 20.sp,
                        ),
                        label: Text(
                          "تصفير العداد",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.redAccent,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
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

  Widget _buildModeBtn(
    String label,
    bool isTarget,
    bool isDark,
    Color borderColor,
    Color textColor,
  ) {
    bool isSelected = _isTargetMode == isTarget;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isTargetMode = isTarget;
          _counter = 0; // تصفير عند تغيير الوضع
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? borderColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? borderColor
                : (isDark ? Colors.grey : Colors.grey.shade400),
            width: 1.0.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : textColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }
}
