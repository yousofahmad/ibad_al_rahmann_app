import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/widgets_ext.dart';
import 'package:ibad_al_rahmann/core/widgets/top_bar_widget.dart';
import 'package:ibad_al_rahmann/features/qiblah/qiblah_compass.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QiblahScreen extends StatelessWidget {
  const QiblahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: TopBar(
              height: context.isLandscape ? 350.h : 280.h,
              label: 'القبلة',
            ),
          ),
          Positioned.fill(top: 280.h, child: const QiblahCompass()),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20.sp),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8.h),
                      Text(
                        "يشير السهم إلى اتجاه القبلة. وللحصول على نتيجة دقيقة حرّك جهازك يمينًا أو يسارًا بشكل دائري.\nواحرص على أن يكون جهازك بعيدًا عن أي أجهزة إلكترونية أو مجال مغناطيسي حول الجهاز؛ حتى لا يؤثر ذلك في دقة البوصلة.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                          height: 1.5,
                          fontFamily: 'Cairo',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ).withSafeArea(),
    );
  }
}
