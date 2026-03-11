import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_styles.dart';
import 'quran_theme_extension.dart';

import 'package:flutter/services.dart';

class AppThemes {
  // Standard App Themes (Gold)
  static final goldLight = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: const Color(0xFFD0A871),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F9FA),
      scrolledUnderElevation: 0,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light bg
        statusBarBrightness: Brightness.light, // iOS
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0A871),
      brightness: Brightness.light,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    useMaterial3: true,
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final goldDark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: const Color(0xFFD0A871),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Light icons for dark bg
        statusBarBrightness: Brightness.dark, // iOS
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0A871),
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
    useMaterial3: true,
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final red = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    scaffoldBackgroundColor: AppColors.red,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.red,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    primaryColor: AppColors.red,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.red,
      secondary: AppColors.darkRed,
      surface: AppColors.lightRed,
      outline: AppColors.outlineRed,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.white),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.black),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.black),
      titleSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 24.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      labelSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      bodySmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      labelMedium: TextStyle(
        fontFamily: AppConsts.expoArabic,
        fontSize: 16.sp,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: const Color.fromARGB(242, 255, 255, 255),
      ),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final cyan = lightBlue.copyWith(
    scaffoldBackgroundColor: AppColors.cyan,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cyan,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    primaryColor: AppColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.darkCyan,
      surface: AppColors.lightCyan,
      outline: AppColors.outlineCyan,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final green = lightBlue.copyWith(
    scaffoldBackgroundColor: AppColors.darkGreen,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkGreen,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    primaryColor: AppColors.darkGreen,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkGreen,
      secondary: AppColors.greenShadow,
      surface: AppColors.lightGreen,
      outline: Color.fromARGB(255, 77, 87, 60),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final lightBlue = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.blue,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blue,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    primaryColor: AppColors.blue,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      secondary: AppColors.darkBlue,
      surface: AppColors.lightBlue,
      outline: AppColors.outlineBlue,
      onPrimary: AppColors.lightYellow,
      onSecondary: Colors.black,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.white),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.black),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.black),
      displaySmall: AppStyles.style22u.copyWith(color: Colors.white),
      titleSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 24.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      labelSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      bodySmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
      labelMedium: TextStyle(
        fontFamily: AppConsts.expoArabic,
        fontSize: 16.sp,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 18.sp,
        fontWeight: FontWeight.normal,
        color: const Color.fromARGB(242, 255, 255, 255),
      ),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );
  static final darkBlue = lightBlue.copyWith(
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    colorScheme: lightBlue.colorScheme.copyWith(
      onPrimary: AppColors.black,
      onSecondary: Colors.white,
    ),
    textTheme: lightBlue.textTheme.copyWith(
      headlineLarge: lightBlue.textTheme.headlineLarge!,
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      labelSmall: lightBlue.textTheme.labelSmall!.copyWith(color: Colors.white),
      titleSmall: lightBlue.textTheme.titleSmall!.copyWith(color: Colors.white),
      headlineMedium: lightBlue.textTheme.titleSmall!.copyWith(
        color: Colors.white,
      ),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final darkRed = red.copyWith(
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    colorScheme: red.colorScheme.copyWith(
      onPrimary: AppColors.black,
      onSecondary: Colors.white,
    ),
    textTheme: red.textTheme.copyWith(
      headlineLarge: red.textTheme.headlineLarge!,
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      labelSmall: red.textTheme.labelSmall!.copyWith(color: Colors.white),
      titleSmall: red.textTheme.titleSmall!.copyWith(color: Colors.white),
      headlineMedium: red.textTheme.titleSmall!.copyWith(color: Colors.white),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final darkCyan = cyan.copyWith(
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    colorScheme: cyan.colorScheme.copyWith(
      onPrimary: AppColors.black,
      onSecondary: Colors.white,
    ),
    textTheme: cyan.textTheme.copyWith(
      headlineLarge: cyan.textTheme.headlineLarge!,
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      labelSmall: cyan.textTheme.labelSmall!.copyWith(color: Colors.white),
      titleSmall: cyan.textTheme.titleSmall!.copyWith(color: Colors.white),
      headlineMedium: cyan.textTheme.titleSmall!.copyWith(color: Colors.white),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final darkGreen = green.copyWith(
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightYellow,
    ),
    colorScheme: green.colorScheme.copyWith(
      onPrimary: AppColors.black,
      onSecondary: Colors.white,
    ),
    textTheme: green.textTheme.copyWith(
      headlineLarge: green.textTheme.headlineLarge!,
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      labelSmall: green.textTheme.labelSmall!.copyWith(color: Colors.white),
      titleSmall: green.textTheme.titleSmall!.copyWith(color: Colors.white),
      headlineMedium: green.textTheme.titleSmall!.copyWith(color: Colors.white),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  // Get all available themes
  static Map<String, ThemeData> get allThemes => {
    'gold': goldLight,
    'blue': lightBlue,
    'red': red,
    'cyan': cyan,
    'green': green,
  };

  // Get theme by name
  static ThemeData? getThemeByName(String name) {
    return allThemes[name];
  }

  // Get theme names
  static List<String> get themeNames => allThemes.keys.toList();
}
