import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/screens/splash_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:ibad_al_rahmann/screens/home_screen.dart';

class QuranApp extends StatelessWidget {
  const QuranApp({super.key, required this.showCustomSplash});
  final bool showCustomSplash;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392.72, 800.72),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, state) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'القرآن الكريم',
              theme: state.theme.light,
              darkTheme: state.theme.dark,
              themeMode: state.mode,
              locale: const Locale('ar'),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('ar')],
              home: showCustomSplash
                  ? const SplashScreen()
                  : const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
