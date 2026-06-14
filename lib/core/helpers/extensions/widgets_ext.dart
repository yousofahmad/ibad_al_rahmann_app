import 'package:flutter/widgets.dart';

extension WidgetsExt on Widget {
  Widget withSafeArea() {
    return SafeArea(
      top: false,
      bottom: false,
      right: false,
      left: false,
      child: this,
    );
  }
}
