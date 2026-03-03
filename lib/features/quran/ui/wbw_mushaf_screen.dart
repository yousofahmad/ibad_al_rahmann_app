import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/theme_manager/theme_cubit.dart';
import 'widgets/wbw_page_widget.dart';
import 'layouts/mobile_quran_top_bar.dart';
import 'layouts/mobile_min_quran_bottom_section.dart';

class WbwMushafScreen extends StatefulWidget {
  const WbwMushafScreen({super.key});

  @override
  State<WbwMushafScreen> createState() => _WbwMushafScreenState();
}

class _WbwMushafScreenState extends State<WbwMushafScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
    final paperColor = isDark ? Colors.black : const Color(0xfffffdf5);

    // Set status bar to match Mushaf paper color
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: paperColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: paperColor,
      body: SafeArea(
        child: Column(
          children: [
            const MobileQuranTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 604,
                reverse: true,
                itemBuilder: (context, index) {
                  return WbwPageWidget(
                    pageNumber: index + 1,
                    isZoomEnabled: true,
                  );
                },
              ),
            ),
            const MobileMinQuranBottomSection(),
          ],
        ),
      ),
    );
  }
}
