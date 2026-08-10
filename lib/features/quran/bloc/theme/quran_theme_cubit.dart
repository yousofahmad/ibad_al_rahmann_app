import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/cache_keys.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/theme/app_themes.dart';
import 'package:ibad_al_rahmann/core/theme/custom_theme_model.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';

class QuranThemeCubit extends ThemeCubit {
  final _cache = getIt<CacheService>();

  QuranThemeCubit() : super() {
    _init();
  }

  @override
  Future<void> reload() async {
    await _init();
  }

  Future<void> _init() async {
    // Load saved theme using Quran-specific keys (Isolated from main app)
    final savedThemeKey = await _cache.getString(CacheKeys.quranSelectedTheme);
    final themeMode = await _cache.getString(CacheKeys.quranThemeMode);

    if (savedThemeKey != null && savedThemeKey.startsWith('custom_')) {
      try {
        final hexString = savedThemeKey.replaceFirst('custom_', '');
        final color = Color(int.parse(hexString, radix: 16));
        _quranThemes[savedThemeKey] = AppThemes.createCustomTheme(color);
      } catch (e) {
        debugPrint('Error parsing color in _init: $e');
      }
    }

    // Default to Blue for Mushaf per user request
    CustomTheme selectedTheme =
        _quranThemes[savedThemeKey] ?? _quranThemes['blue']!;
    ThemeMode mode;

    if (themeMode == CacheKeys.darkTheme) {
      mode = ThemeMode.dark;
    } else if (themeMode == CacheKeys.lightTheme) {
      mode = ThemeMode.light;
    } else {
      // No saved preference, use System Default
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (brightness == Brightness.dark) {
        mode = ThemeMode.dark;
      } else {
        mode = ThemeMode.light;
      }
    }

    emit(ThemeChanged(theme: selectedTheme, mode: mode));
  }

  @override
  void switchTheme() {
    if (state.mode == ThemeMode.light) {
      _cache.setString(CacheKeys.quranThemeMode, CacheKeys.darkTheme);
      emit(ThemeChanged(theme: state.theme, mode: ThemeMode.dark));
    } else {
      _cache.setString(CacheKeys.quranThemeMode, CacheKeys.lightTheme);
      emit(ThemeChanged(theme: state.theme, mode: ThemeMode.light));
    }
  }

  @override
  void selectTheme(String themeKey) async {
    if (themeKey.startsWith('custom_')) {
      try {
        final hexString = themeKey.replaceFirst('custom_', '');
        final color = Color(int.parse(hexString, radix: 16));
        _quranThemes[themeKey] = AppThemes.createCustomTheme(color);
      } catch (e) {
        debugPrint('Error parsing color in selectTheme: $e');
      }
    }

    if (_quranThemes.containsKey(themeKey)) {
      final selectedTheme = _quranThemes[themeKey]!;
      await _cache.setString(CacheKeys.quranSelectedTheme, themeKey);
      emit(ThemeChanged(theme: selectedTheme, mode: state.mode));
    }
  }

  @override
  Future<String?> getCurrentThemeKey() {
    return _cache.getString(CacheKeys.quranSelectedTheme);
  }
}

// Private map duplicate for Quran-specific themes
final Map<String, CustomTheme> _quranThemes = {
  'blue': CustomTheme(light: AppThemes.mushafBlue, dark: AppThemes.darkBlue),
  'red': CustomTheme(light: AppThemes.red, dark: AppThemes.darkRed),
  'cyan': CustomTheme(light: AppThemes.cyan, dark: AppThemes.darkCyan),
  'green': CustomTheme(light: AppThemes.green, dark: AppThemes.darkGreen),
};
