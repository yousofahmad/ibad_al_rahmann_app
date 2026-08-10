part of 'theme_cubit.dart';

sealed class ThemeState {
  final CustomTheme theme;
  final ThemeMode mode;

  ThemeState({required this.theme, required this.mode});
}

final class ThemeInitial extends ThemeState {
  ThemeInitial({required super.theme, required super.mode});
}

final class ThemeChanged extends ThemeState {
  ThemeChanged({required super.theme, required super.mode});
}
