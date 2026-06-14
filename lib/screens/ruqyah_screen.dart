import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ضروري عشان النسخ Clipboard
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';

class RuqyahScreen extends StatefulWidget {
  const RuqyahScreen({super.key});

  @override
  State<RuqyahScreen> createState() => _RuqyahScreenState();
}

class _RuqyahScreenState extends State<RuqyahScreen> {
  Future<List<dynamic>> loadRuqyah() async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/data/ruqyah.json',
      );
      return json.decode(jsonString);
    } catch (e) {
      debugPrint("خطأ في تحميل الرقية: $e");
      return [];
    }
  }

  // دالة النسخ
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم نسخ النص بنجاح",
          style: TextStyle(fontFamily: AppConsts.expoArabic),
        ),
        backgroundColor: Color(0xFFD0A871),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'الرقية الشرعية',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: loadRuqyah(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: 6,
                itemBuilder: (_, __) => AppSkeleton.card(height: 100.h),
              );
            } else if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "لا توجد بيانات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                  ),
                ),
              );
            }

            final ruqyahList = snapshot.data!;

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(15.w, 10.h, 15.w, 15.h),
              physics: const BouncingScrollPhysics(),
              itemCount: ruqyahList.length,
              itemBuilder: (context, index) {
                final item = ruqyahList[index];
                final text =
                    item['zekr'] ??
                    item['ARABIC_TEXT'] ??
                    item['content'] ??
                    '';

                return Container(
                  margin: EdgeInsets.only(bottom: 15.h),
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10.r,
                        offset: Offset(0, 5.h),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFD0A871),
                      width: 1.5.w,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppConsts.amiri,
                          fontSize: 22.sp,
                          height: 1.8,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 15.h),
                      Divider(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      ),

                      // زر النسخ الجديد
                      InkWell(
                        onTap: () => _copyToClipboard(text),
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD0A871,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "نسخ",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Color(0xFFD0A871),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.copy,
                                color: const Color(0xFFD0A871),
                                size: 18.w,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
