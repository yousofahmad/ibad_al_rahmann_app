import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/widgets_ext.dart';
import 'package:ibad_al_rahmann/core/widgets/top_bar_widget.dart';
import 'package:ibad_al_rahmann/features/qiblah/qiblah_compass.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter/services.dart';

class QiblahScreen extends StatefulWidget {
  const QiblahScreen({super.key});

  @override
  State<QiblahScreen> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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

  @override
  Widget build(BuildContext context) {
    final topBarHeight = context.isLandscape ? 350.h : 280.h;
    return Scaffold(
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────
          SizedBox(
            height: topBarHeight,
            child: Stack(
              children: [
                TopBar(
                  height: topBarHeight,
                  withBackButton: false, // لا يوجد زر رجوع في القبلة
                  label: 'القبلة',
                ),
              ],
            ),
          ),

          // ─── Compass (Expanded = يأخذ كل المساحة المتبقية) ──
          const Expanded(child: QiblahCompass()),

          // ─── Note text at the bottom ──────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Text(
                "يشير السهم إلى اتجاه القبلة. وللحصول على نتيجة دقيقة حرّك جهازك يمينًا أو يسارًا بشكل دائري.\nواحرص على أن يكون جهازك بعيدًا عن أي أجهزة إلكترونية أو مجال مغناطيسي حول الجهاز؛ حتى لا يؤثر ذلك في دقة البوصلة.",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12.sp,
                  height: 1.5,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ).withSafeArea(),
    );
  }
}
