import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';

class QuranThemeSelectionDialog extends StatelessWidget {
  const QuranThemeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCubit = context.read<QuranThemeCubit>();
    final currentTheme = themeCubit.state.theme.dark;

    final List<Map<String, dynamic>> themes = [
      {'name': 'اللون الأزرق', 'key': 'blue', 'color': const Color(0xFF1565C0)},
      {'name': 'اللون الأحمر', 'key': 'red', 'color': const Color(0xFFC62828)},
      {
        'name': 'اللون السماوي',
        'key': 'cyan',
        'color': const Color(0xFF00838F),
      },
      {
        'name': 'اللون الأخضر',
        'key': 'green',
        'color': const Color(0xFF2E7D32),
      },
      {
        'name': 'لون مخصص',
        'key': 'custom',
        'color': Colors.black, // fallback changed to black
      },
    ];

    void showColorPicker(BuildContext ctx, String currentThemeKey) {
      Color pickerColor = const Color(0xFF1565C0);
      if (currentThemeKey.startsWith('custom_')) {
        final hex = currentThemeKey.replaceFirst('custom_', '');
        try {
          pickerColor = Color(int.parse(hex, radix: 16));
        } catch (_) {}
      }

      showDialog(
        context: ctx,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'اختر لون التطبيق',
              style: TextStyle(fontFamily: 'cairo', color: Colors.black),
            ),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  pickerColor = color;
                },
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text(
                  'حفظ',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // ignore: deprecated_member_use
                  final hex = pickerColor.value
                      .toRadixString(16)
                      .padLeft(8, '0');
                  themeCubit.selectTheme('custom_$hex');
                  Navigator.of(context).pop(); // close color picker
                  Navigator.of(ctx).pop(); // close theme dialog
                },
              ),
            ],
          );
        },
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: currentTheme.primaryColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ألوان التطبيق الأساسية',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'cairo',
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 15.h,
                childAspectRatio: 0.85,
              ),
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final item = themes[index];
                final String name = item['name'];

                return FutureBuilder<String?>(
                  future: themeCubit.getCurrentThemeKey(),
                  builder: (context, snapshot) {
                    final currentThemeKey = snapshot.data ?? 'blue';
                    final bool isCustomSelection = item['key'] == 'custom';

                    bool isSelected = false;
                    Color colorToDisplay = item['color'] ?? Colors.grey;

                    if (isCustomSelection) {
                      isSelected = currentThemeKey.startsWith('custom_');
                      if (isSelected) {
                        try {
                          colorToDisplay = Color(
                            int.parse(
                              currentThemeKey.replaceFirst('custom_', ''),
                              radix: 16,
                            ),
                          );
                        } catch (_) {}
                      }
                    } else {
                      isSelected = currentThemeKey == item['key'];
                    }

                    return GestureDetector(
                      onTap: () {
                        if (isCustomSelection) {
                          showColorPicker(context, currentThemeKey);
                        } else {
                          themeCubit.selectTheme(item['key']);
                          Navigator.pop(context);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50.w,
                            height: 50.w,
                            decoration: BoxDecoration(
                              color: colorToDisplay,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white30,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: isSelected && !isCustomSelection
                                ? Icon(
                                    Icons.check,
                                    color:
                                        colorToDisplay.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : isCustomSelection
                                ? const Icon(
                                    Icons.colorize,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontFamily: 'cairo',
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
