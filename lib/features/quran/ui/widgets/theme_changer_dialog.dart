import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ThemeChangerDialog extends StatefulWidget {
  const ThemeChangerDialog({super.key});

  @override
  State<ThemeChangerDialog> createState() => _ThemeChangerDialogState();
}

class _ThemeChangerDialogState extends State<ThemeChangerDialog> {
  String? selectedTheme;

  void init() async {
    final themeCubit = context.read<ThemeCubit>();
    selectedTheme = await themeCubit.getCurrentThemeKey();
  }

  @override
  void initState() {
    super.initState();
    // Get current theme from ThemeCubit
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: context.primaryColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: context.outline,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر لون المظهر',
              style: context.headlineLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            _buildColorGrid(context),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context: context,
                  text: 'إلغاء',
                  onPressed: () => Navigator.of(context).pop(),
                  isPrimary: false,
                ),
                _buildActionButton(
                  context: context,
                  text: 'تطبيق',
                  onPressed: selectedTheme != null
                      ? () {
                          _applyTheme(context, selectedTheme!);
                        }
                      : null,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorGrid(BuildContext context) {
    final colorOptions = [
      {
        'name': 'أزرق',
        'themeKey': 'blue',
        'color': AppColors.blue,
        'darkColor': AppColors.darkBlue,
        'lightColor': AppColors.lightBlue,
        'outlineColor': AppColors.outlineBlue,
      },
      {
        'name': 'أخضر',
        'themeKey': 'green',
        'color': AppColors.darkGreen,
        'darkColor': AppColors.greenShadow,
        'lightColor': AppColors.lightGreen,
        'outlineColor': AppColors.lime,
      },
      {
        'name': 'أحمر',
        'themeKey': 'red',
        'color': AppColors.red,
        'darkColor': AppColors.darkRed,
        'lightColor': AppColors.lightRed,
        'outlineColor': AppColors.outlineRed,
      },
      {
        'name': 'سماوي',
        'themeKey': 'cyan',
        'color': AppColors.cyan,
        'darkColor': AppColors.darkCyan,
        'lightColor': AppColors.lightCyan,
        'outlineColor': AppColors.outlineCyan,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.5,
      ),
      itemCount: colorOptions.length,
      itemBuilder: (context, index) {
        final option = colorOptions[index];
        final themeKey = option['themeKey'] as String;
        final isSelected = selectedTheme == themeKey;
        return _buildColorOption(
          context: context,
          name: option['name'] as String,
          themeKey: themeKey,
          primaryColor: option['color'] as Color,
          darkColor: option['darkColor'] as Color,
          lightColor: option['lightColor'] as Color,
          outlineColor: option['outlineColor'] as Color,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildColorOption({
    required BuildContext context,
    required String name,
    required String themeKey,
    required Color primaryColor,
    required Color darkColor,
    required Color lightColor,
    required Color outlineColor,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTheme = themeKey;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, darkColor],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? Colors.white : outlineColor,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha(isSelected ? 123 : 77),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
            if (isSelected)
              BoxShadow(
                color: Colors.white.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(123),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: 100.w,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null
              ? (isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface)
              : Theme.of(context).colorScheme.surface.withAlpha(123),
          foregroundColor: onPressed != null
              ? (isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface)
              : Theme.of(context).colorScheme.onSurface.withAlpha(123),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 6.h),
        ),
        child: Text(text, style: context.headlineLarge),
      ),
    );
  }

  void _applyTheme(BuildContext context, String themeKey) {
    final themeCubit = context.read<ThemeCubit>();
    themeCubit.selectTheme(themeKey);
    AlertHelper.showSuccessAlert(context,
        message: 'تم تطبيق المظهر: ${_getThemeDisplayName(themeKey)}');

    Navigator.of(context).pop();
  }

  String _getThemeDisplayName(String themeKey) {
    switch (themeKey) {
      case 'blue':
        return 'أزرق';
      case 'red':
        return 'أحمر';
      case 'cyan':
        return 'سماوي';
      case 'green':
        return 'أخضر';

      default:
        return themeKey;
    }
  }
}
