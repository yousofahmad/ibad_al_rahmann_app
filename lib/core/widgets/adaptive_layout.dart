import 'package:flutter/material.dart';

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.mobileLayout,
    required this.tabletLayout,
  });

  final WidgetBuilder mobileLayout;
  final WidgetBuilder tabletLayout;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;
        if (isMobile) {
          return mobileLayout(context);
        } else {
          return tabletLayout(context);
        }
      },
    );
  }
}
