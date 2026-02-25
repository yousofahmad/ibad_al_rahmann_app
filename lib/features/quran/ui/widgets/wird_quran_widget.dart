import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:flutter/services.dart';

import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/full_page_rich_text_mobile.dart';

class WirdQuranWidget extends StatefulWidget {
  final int initialAbsolutePage;

  const WirdQuranWidget({super.key, required this.initialAbsolutePage});

  @override
  State<WirdQuranWidget> createState() => _WirdQuranWidgetState();
}

class _WirdQuranWidgetState extends State<WirdQuranWidget> {
  late PageController _controller;
  @override
  void initState() {
    final cubit = context.read<QuranCubit>();
    final start = cubit.wirdStartPage ?? 1; // 1-based
    final initialRelative = widget.initialAbsolutePage - (start - 1);

    _controller = PageController(
      initialPage: initialRelative > 0 ? initialRelative : 0,
    );

    _showDoubleTapHint();
    super.initState();
  }

  void _showDoubleTapHint() {
    // Show a small hint that double tap changes theme
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "اضغط مرتين لتغيير لون مصحف الورد",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 16.sp,
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFD0A871).withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _toggleTheme() {
    context.read<ThemeCubit>().switchTheme();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranCubit>();
    final start = cubit.wirdStartPage ?? 1; // 1-based
    final end = cubit.targetEndPage ?? start; // 1-based
    final count = end - start + 1;

    return Stack(
      children: [
        // The Background Restricted PageView
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: _toggleTheme,
            child: ColoredBox(
              color: context.watch<ThemeCubit>().state.mode == ThemeMode.light
                  ? Colors.white
                  : context.onPrimary,
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (relativeIndex) {
                  final absoluteIndex = relativeIndex + (start - 1);
                  cubit.onQuranPageChanged(absoluteIndex);
                },
                itemBuilder: (context, relativeIndex) {
                  final realPageIndex = relativeIndex + (start - 1); // 0-based
                  return Column(
                    children: [
                      Expanded(
                        child: FullPageRichText(pageNumber: realPageIndex + 1),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
