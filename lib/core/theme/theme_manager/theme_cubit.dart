import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/cache_keys.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/theme/app_themes.dart';

import '../custom_theme_model.dart';

part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit()
    : super(ThemeInitial(theme: _themes['gold']!, mode: ThemeMode.light)) {
    _init();
  }
  final _cache = getIt<CacheService>();

  Future<void> _init() async {
    // Load saved theme
    final savedThemeKey = await _cache.getString(CacheKeys.selectedTheme);
    final themeMode = await _cache.getString(CacheKeys.themeMode);

    CustomTheme selectedTheme = _themes[savedThemeKey ?? 'gold']!;
    ThemeMode mode;

    if (savedThemeKey != null && _themes.containsKey(savedThemeKey)) {
      selectedTheme = _themes[savedThemeKey]!;
    }

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

  void switchTheme() {
    if (state.mode == ThemeMode.light) {
      _cache.setString(CacheKeys.themeMode, CacheKeys.darkTheme);
      emit(ThemeChanged(theme: state.theme, mode: ThemeMode.dark));
    } else {
      _cache.setString(CacheKeys.themeMode, CacheKeys.lightTheme);
      emit(ThemeChanged(theme: state.theme, mode: ThemeMode.light));
    }
  }

  void selectTheme(String themeKey) async {
    if (_themes.containsKey(themeKey)) {
      final selectedTheme = _themes[themeKey]!;
      await _cache.setString(CacheKeys.selectedTheme, themeKey);
      emit(ThemeChanged(theme: selectedTheme, mode: state.mode));
    }
  }

  Future<String?> getCurrentThemeKey() {
    return _cache.getString(CacheKeys.selectedTheme);
  }
}

final Map<String, CustomTheme> _themes = {
  'gold': CustomTheme(light: AppThemes.goldLight, dark: AppThemes.goldDark),
  'blue': CustomTheme(light: AppThemes.lightBlue, dark: AppThemes.darkBlue),
  'red': CustomTheme(light: AppThemes.red, dark: AppThemes.darkRed),
  'cyan': CustomTheme(light: AppThemes.cyan, dark: AppThemes.darkCyan),
  'green': CustomTheme(light: AppThemes.green, dark: AppThemes.darkGreen),
};
