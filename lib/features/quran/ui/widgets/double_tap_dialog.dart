import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class DoubleTapDialog extends StatelessWidget {
  const DoubleTapDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, color: AppColors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            'اضغط ضغطتين لتكبير الصفحة',
            style: context.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك تكبير الشاشة عبر الضغط مرتين على الآيات',
            style: context.headlineLarge.copyWith(fontSize: 20.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'حسنًا',
            style: TextStyle(
              color: AppColors.white,
              fontFamily: AppConsts.uthmanic,
            ),
          ),
        ),
      ],
    );
  }
}
