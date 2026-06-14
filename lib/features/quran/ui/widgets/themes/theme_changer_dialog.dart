import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';

class ThemeChangerDialog extends StatefulWidget {
  const ThemeChangerDialog({super.key});

  @override
  State<ThemeChangerDialog> createState() => _ThemeChangerDialogState();
}

class _ThemeChangerDialogState extends State<ThemeChangerDialog> {
  // ─── preset palette ──────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _presets = [
    {'name': 'أبيض ناصع', 'color': Colors.white, 'mode': ThemeMode.light},
    {'name': 'أبيض كريمي', 'color': Color(0xFFFFF9E5), 'mode': ThemeMode.light},
    {'name': 'ورق قديم', 'color': Color(0xFFF5F5DC), 'mode': ThemeMode.light},
    {'name': 'أسود ناصع', 'color': Colors.black, 'mode': ThemeMode.dark},
    {'name': 'رمادي ليلي', 'color': Color(0xFF1E1E1E), 'mode': ThemeMode.dark},
    {'name': 'كحلي داكن', 'color': Color(0xFF001F3F), 'mode': ThemeMode.dark},
  ];

  /// Returns true when [c] is light enough that black text is readable.
  static bool _isLight(Color c) => c.computeLuminance() > 0.35;

  // ─── open custom-picker bottom-sheet ─────────────────────────────────────
  void _openCustomPicker(
    BuildContext ctx,
    QuranCubit quranCubit,
    ThemeCubit themeCubit,
    Color startColor,
  ) {
    Color picked = startColor;

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final textOnPicked = _isLight(picked)
                ? Colors.black87
                : Colors.white;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── drag handle
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(80),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // ── title
                  Text(
                    'اختر لون الخلفية',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ── live preview strip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: picked,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.grey.withAlpha(80),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ',
                        style: TextStyle(
                          fontFamily: 'uthmanic',
                          fontSize: 16.sp,
                          color: textOnPicked,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ── HSV picker
                  SlidePicker(
                    pickerColor: picked,
                    enableAlpha: false,
                    colorModel: ColorModel.hsv,
                    displayThumbColor: true,
                    onColorChanged: (c) => setSheetState(() => picked = c),
                  ),
                  SizedBox(height: 24.h),

                  // ── info label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 14.sp, color: Colors.grey),
                      SizedBox(width: 6.w),
                      Text(
                        _isLight(picked)
                            ? 'لون فاتح — الخط سيكون أسود'
                            : 'لون غامق — الخط سيكون أبيض',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── apply button
                  ElevatedButton(
                    onPressed: () {
                      final mode = _isLight(picked)
                          ? ThemeMode.light
                          : ThemeMode.dark;
                      themeCubit.forceThemeMode(mode);
                      
                      if (quranCubit.state.isKahfMode) {
                        quranCubit.setKahfColor(picked);
                      } else if (quranCubit.state.isWirdMode) {
                        quranCubit.setWirdColor(picked);
                      } else {
                        quranCubit.setPaperColor(picked);
                      }
                      
                      Navigator.pop(sheetCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 46.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'تطبيق اللون',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final quranCubit = context.watch<QuranCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final isDark = themeCubit.state.mode == ThemeMode.dark;
    final isWirdMode = quranCubit.state.isWirdMode;
    final isKahfMode = quranCubit.state.isKahfMode;

    const Color creamFallback = Color(0xFFFFF9E5);

    // Effective paper color based on mode with unified cream fallback
    final Color effectivePaperColor = isKahfMode
        ? (quranCubit.state.kahfPaperColor ?? creamFallback)
        : (isWirdMode
            ? (quranCubit.state.wirdPaperColor ?? creamFallback)
            : (quranCubit.state.quranPaperColor ?? (isDark ? Colors.black : creamFallback)));

    // Is the current color a custom (non-preset) one?
    final bool isCustom = !_presets.any(
      (p) => (p['color'] as Color).toARGB32() == effectivePaperColor.toARGB32(),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── title
            Text(
              isKahfMode
                  ? 'ألوان خلفية الكهف'
                  : (isWirdMode ? 'ألوان خلفية الورد' : 'ألوان خلفية المصحف'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'cairo',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 20.h),

            // ── preset grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 15.h,
                childAspectRatio: 0.8,
              ),
              itemCount: _presets.length,
              itemBuilder: (context, index) {
                final item = _presets[index];
                final Color color = item['color'] as Color;
                final String name = item['name'] as String;
                final ThemeMode mode = item['mode'] as ThemeMode;
                final bool isSelected =
                    effectivePaperColor.toARGB32() == color.toARGB32();

                return GestureDetector(
                  onTap: () {
                    themeCubit.forceThemeMode(mode);
                    if (isKahfMode) {
                      quranCubit.setKahfColor(color);
                    } else if (isWirdMode) {
                      quranCubit.setWirdColor(color);
                    } else {
                      quranCubit.setPaperColor(color);
                    }
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50.w,
                        height: 50.w,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.grey.withAlpha(100),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withAlpha(100),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: _isLight(color)
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontFamily: 'cairo',
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 16.h),

            // ── custom-color button
            GestureDetector(
              onTap: () => _openCustomPicker(
                context,
                quranCubit,
                themeCubit,
                effectivePaperColor,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isCustom
                      ? effectivePaperColor
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isCustom
                        ? Colors.greenAccent
                        : Colors.grey.withAlpha(80),
                    width: isCustom ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // rainbow gradient circle
                    Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.grey.withAlpha(80),
                          width: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      isCustom ? 'لون مخصص ✓' : 'اختر لونًا مخصصًا',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontWeight: isCustom
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13.sp,
                        color: isCustom
                            ? (_isLight(effectivePaperColor)
                                  ? Colors.black87
                                  : Colors.white)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // ── reset button
            TextButton(
              onPressed: () {
                if (isKahfMode) {
                  quranCubit.setKahfColor(null);
                } else if (isWirdMode) {
                  quranCubit.setWirdColor(null);
                } else {
                  quranCubit.setPaperColor(null);
                }
              },
              child: Text(
                'إعادة للوضع التلقائي',
                style: TextStyle(
                  fontFamily: 'cairo',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            SizedBox(height: 8.h),

            // ── margin slider
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_indent_increase_rounded, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'هامش الصفحة',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${quranCubit.state.quranPageMargin.toInt()}',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.sp,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: 40,
                    value: quranCubit.state.quranPageMargin,
                    onChanged: (val) {
                      quranCubit.setPageMargin(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // ── close button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 45.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'cairo')),
            ),
          ],
        ),
      ),
    );
  }
}
