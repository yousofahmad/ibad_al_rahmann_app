import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/widgets/adaptive_layout.dart';
import 'package:ibad_al_rahmann/features/quran/ui/layouts/min_quran_mobile.dart';
import 'package:ibad_al_rahmann/features/quran/ui/layouts/min_quran_tablet.dart';

class MinQuranWidget extends StatelessWidget {
  const MinQuranWidget({super.key, required this.currentPage});
  final int? currentPage;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobileLayout: (_) => MinQuranMobile(currentPage: currentPage),
      tabletLayout: (_) => MinQuranTablet(currentPage: currentPage),
    );
  }
}
