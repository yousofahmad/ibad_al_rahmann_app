import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/size_config.dart';

extension ScreenDetails on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isTablet =>
      (isLandscape ? screenHeight : screenWidth) >= SizeConfig.tablet;
  double get topPadding => MediaQuery.of(this).padding.top;

  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  bool get isTabOrLand => isLandscape || isTablet;
}
