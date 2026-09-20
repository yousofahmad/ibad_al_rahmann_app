import 'package:flutter/material.dart';

/// Custom page scroll physics that requires less swipe distance to turn pages.
/// The default PageScrollPhysics requires ~50% swipe. This one triggers at ~25%.
class EasyPageScrollPhysics extends PageScrollPhysics {
  const EasyPageScrollPhysics({super.parent});

  @override
  EasyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EasyPageScrollPhysics(parent: buildParent(ancestor));
  }

  /// Lower velocity threshold = easier to fling to next page.
  /// Default PageScrollPhysics is ~365. We use 80 for comfortable swipe.
  @override
  double get minFlingVelocity => 20.0;

  /// Use PageScrollPhysics default spring (critically damped, no oscillation).
  /// Do NOT override spring here — overriding with custom values caused
  /// underdamped oscillation (pendulum bounce effect).
}
