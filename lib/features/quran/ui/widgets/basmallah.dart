import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';

class Basmallah extends StatelessWidget {
  final bool isFull;
  final Color? color;

  const Basmallah({super.key, required this.isFull, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.screenWidth,
      child: Padding(
        padding: EdgeInsets.only(
          left: (context.screenWidth * (isFull ? .2 : .15)),
          right: (context.screenWidth * (isFull ? .2 : .15)),
          top: 4,
        ),
        child: Image.asset(
          AppImages.basmala,
          color: color ?? context.onSecondary,
          width: context.screenWidth,
        ),
      ),
    );
  }
}

class TabletBasmallah extends StatelessWidget {
  final bool isFull;
  final Color? color;

  const TabletBasmallah({super.key, required this.isFull, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.screenWidth,
      child: Padding(
        padding: EdgeInsets.only(
          left: (context.screenWidth * (isFull ? .2 : .1)),
          right: (context.screenWidth * (isFull ? .2 : .1)),
          top: 4,
        ),
        child: Image.asset(
          AppImages.basmala,
          color: color ?? context.onSecondary,
          width: context.screenWidth * .4,
        ),
      ),
    );
  }
}
