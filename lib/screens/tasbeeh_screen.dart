import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

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
    _loadSettings();
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
        ? const Color(0xFF1E1E1E).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);
    const Color borderColor = Color(0xFFD0A871);
    final Color scaffoldBgColor = isDark
        ? Colors.black
        : const Color(0xFFF5F5F5);
    final Color appBarBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: scaffoldBgColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: appBarBgColor,
          centerTitle: true,
          toolbarHeight: 55,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: borderColor,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'التسبيح',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: borderColor,
              fontSize: 18,
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
              const SizedBox(height: 20),
              // خانة إضافة ذكر
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _zekrController,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: mainTextColor,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "أضف ذكرك هنا (اختياري)...",
                      hintStyle: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        color: mainTextColor.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // حاوية العداد
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: List.generate(12, (index) {
                              int loopTarget = _isTargetMode ? _target : 100;
                              double angle = (index * 30) * (pi / 180);
                              double radius = 75;
                              double progress =
                                  (_counter % loopTarget) / loopTarget;
                              if (_counter > 0 && _counter % loopTarget == 0) {
                                progress = 1.0;
                              }
                              int activeBeads = (progress * 12).floor();
                              bool isActive =
                                  index < activeBeads || (progress == 1.0);

                              return Positioned(
                                left: 90 + radius * cos(angle) - 5,
                                top: 90 + radius * sin(angle) - 5,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 10,
                                  height: 10,
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
                                              blurRadius: 4,
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
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: borderColor,
                              ),
                            ),
                            Text(
                              _isTargetMode ? 'من $_target' : 'وضع مفتوح',
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14,
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
              const SizedBox(height: 30),
              // زر التسبيح
              GestureDetector(
                onTap: _incrementCounter,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: isDark ? Colors.black : Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const Spacer(),

              // أدوات التحكم السفلية
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
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
                            const SizedBox(width: 10),
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
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [33, 99, 1000].map((t) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: ChoiceChip(
                              label: Text('$t'),
                              selected: _target == t,
                              onSelected: (val) => _setTarget(t),
                              selectedColor: borderColor,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide.none,
                              ),
                              labelStyle: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: _target == t
                                    ? (isDark ? Colors.black : Colors.white)
                                    : mainTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // زر التصفير
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _resetCounter,
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          "تصفير العداد",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.redAccent,
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? borderColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? borderColor
                : (isDark ? Colors.grey : Colors.grey.shade400),
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
