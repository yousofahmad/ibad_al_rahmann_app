import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';
import 'package:ibad_al_rahmann/core/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PermissionPanel extends StatelessWidget {
  final IconData icon;
  final String title;

  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  const PermissionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.screenWidth,
      decoration: const BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(AppImages.imagesFullWhiteBackground),
        ),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.green),
              SizedBox(height: 16.h),
              Text(
                title,
                style: AppStyles.style22u.copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: AppStyles.style16.copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimaryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.isTablet ? 8 : 0,
                    ),
                    child: Text(
                      primaryLabel,
                      style: AppStyles.style16.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (secondaryLabel != null && onSecondaryPressed != null) ...[
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.isTablet ? 8 : 0,
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: AppStyles.style16.copyWith(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
