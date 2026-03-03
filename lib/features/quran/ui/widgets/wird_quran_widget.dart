import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/wbw_page_widget.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';

class WirdQuranWidget extends StatefulWidget {
  final int initialAbsolutePage;

  const WirdQuranWidget({super.key, required this.initialAbsolutePage});

  @override
  State<WirdQuranWidget> createState() => _WirdQuranWidgetState();
}

class _WirdQuranWidgetState extends State<WirdQuranWidget> {
  late PageController _controller;
  String _currentTheme = 'light';
  bool _isLoadingTheme = true;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<QuranCubit>();
    int start = cubit.wirdStartPage ?? 1;
    int end = cubit.targetEndPage ?? 604;
    int safeAbsolutePage = widget.initialAbsolutePage;

    if (safeAbsolutePage < start - 1 || safeAbsolutePage > end - 1) {
      safeAbsolutePage = start - 1;
    }

    final initialRelative = safeAbsolutePage - (start - 1);
    _controller = PageController(initialPage: initialRelative);

    _loadTheme();
    _showDoubleTapHint();
  }

  Future<void> _loadTheme() async {
    final theme =
        await getIt<CacheService>().getString('wird_reading_theme') ?? 'light';
    if (mounted) {
      setState(() {
        _currentTheme = theme;
        _isLoadingTheme = false;
      });
    }
  }

  void _showDoubleTapHint() {
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

  void _toggleTheme() async {
    final nextTheme = _currentTheme == 'light'
        ? 'sepia'
        : (_currentTheme == 'sepia' ? 'dark' : 'light');

    await getIt<CacheService>().setString('wird_reading_theme', nextTheme);
    if (mounted) {
      setState(() {
        _currentTheme = nextTheme;
      });
    }
  }

  Color _getBackgroundColor(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'dark':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cubit = context.read<QuranCubit>();
    final start = cubit.wirdStartPage ?? 1;
    final end = cubit.targetEndPage ?? start;
    final count = end - start + 1;

    final bgColor = _getBackgroundColor(_currentTheme);
    final isActuallyDark = bgColor.computeLuminance() < 0.4;
    final textColor = isActuallyDark ? Colors.white : Colors.black;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: isActuallyDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: isActuallyDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10.h,
              bottom: 10.h,
              left: 20.w,
              right: 20.w,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: textColor.withAlpha(30)),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: textColor, size: 24.sp),
                ),
                SizedBox(width: 15.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "مصحف الورد",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD0A871),
                      ),
                    ),
                    Text(
                      "من صـ ${start.toArabicNums} إلى ${end.toArabicNums}",
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 10.sp,
                        color: textColor.withAlpha(180),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.palette_outlined, color: textColor),
                  onPressed: _toggleTheme,
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: _toggleTheme,
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (relativeIndex) {
                  final absoluteIndex = relativeIndex + (start - 1);
                  cubit.onQuranPageChanged(absoluteIndex);
                  setState(() {});
                },
                itemBuilder: (context, relativeIndex) {
                  final realPageIndex = relativeIndex + (start - 1);
                  return WbwPageWidget(
                    pageNumber: realPageIndex + 1,
                    isZoomEnabled: true,
                    textColorOverride: textColor,
                    paperColorOverride: bgColor,
                  );
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              border: Border(top: BorderSide(color: textColor.withAlpha(30))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: count > 1
                              ? (_controller.hasClients
                                        ? _controller.page ?? 0
                                        : 0) /
                                    (count - 1)
                              : 1.0,
                          backgroundColor: textColor.withAlpha(20),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFD0A871),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "${((_controller.hasClients ? (_controller.page?.round() ?? 0) : 0) + 1).toArabicNums} / ${count.toArabicNums}",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
