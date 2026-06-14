import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_styles.dart';
import 'quran_theme_extension.dart';
import 'custom_theme_model.dart';

import 'package:flutter/services.dart';

class AppThemes {
  // Standard App Themes (Gold - The Core Identity)
  static final goldLight = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: const Color(0xFFD0A871),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F9FA),
      scrolledUnderElevation: 0,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0A871),
      brightness: Brightness.light,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.black),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.black),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.black),
      bodyLarge: const TextStyle(color: Colors.black),
      bodyMedium: const TextStyle(color: Colors.black87),
      titleSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 24.sp,
        fontWeight: FontWeight.normal,
        color: Colors.black,
      ),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  static final goldDark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: const Color(0xFFD0A871),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0A871),
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.white),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.white),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      bodyLarge: const TextStyle(color: Colors.white),
      bodyMedium: const TextStyle(color: Colors.white70),
      titleSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 24.sp,
        fontWeight: FontWeight.normal,
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

  // Specialized Mushaf Theme (Blue background, forced visual-darkness for readability)
  static final mushafBlue = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.blue,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blue,
      scrolledUnderElevation: 0,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    primaryColor: AppColors.blue,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      secondary: AppColors.darkBlue,
      surface: AppColors.lightBlue,
      onPrimary: AppColors.lightYellow,
      onSecondary: Colors.black,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.white),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.white),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.white),
      displaySmall: AppStyles.style22u.copyWith(color: Colors.white),
      titleSmall: TextStyle(
        fontFamily: AppConsts.uthmanic,
        fontSize: 24.sp,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: const TextStyle(color: Colors.white),
    ),
    extensions: const [
      QuranThemeColors(
        paperColorLight: Colors.white,
        paperColorDark: Colors.black,
      ),
    ],
  );

  // Blue Theme for the Main App (Standard light background with blue accents)
  static final lightBlue = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: AppColors.blue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.style24u.copyWith(color: Colors.black),
      headlineMedium: AppStyles.style22u.copyWith(color: Colors.black),
      headlineSmall: AppStyles.style18u.copyWith(color: Colors.black),
      bodyLarge: const TextStyle(color: Colors.black),
    ),
  );

  static final darkBlue = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: AppColors.blue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
  );

  // Other colors...
  static final red = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: AppColors.red,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.light,
    ),
  );
  static final darkRed = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: AppColors.red,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
  );

  static final cyan = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: AppColors.cyan,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      brightness: Brightness.light,
    ),
  );
  static final darkCyan = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: AppColors.cyan,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
  );

  static final green = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: AppColors.darkGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkGreen,
      brightness: Brightness.light,
    ),
  );
  static final darkGreen = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: AppColors.darkGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkGreen,
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
  );

  static CustomTheme createCustomTheme(Color color) {
    return CustomTheme(
      light: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: color,
        colorScheme: ColorScheme.fromSeed(
          seedColor: color,
          brightness: Brightness.light,
          primary: color,
        ),
      ),
      dark: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: color,
        colorScheme: ColorScheme.fromSeed(
          seedColor: color,
          brightness: Brightness.dark,
          surface: Colors.black,
          primary: color,
        ),
      ),
    );
  }

  static Map<String, ThemeData> get allThemes => {
    'gold': goldLight,
    'blue': lightBlue,
    'red': red,
    'cyan': cyan,
    'green': green,
  };

  static ThemeData? getThemeByName(String name) => allThemes[name];
  static List<String> get themeNames => allThemes.keys.toList();
}
