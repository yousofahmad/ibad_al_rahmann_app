import 'package:flutter/material.dart';

/// Custom page scroll physics that requires less swipe distance to turn pages.
/// The default PageScrollPhysics requires ~50% swipe. This one triggers at ~30%.
class EasyPageScrollPhysics extends ScrollPhysics {
  const EasyPageScrollPhysics({super.parent});

  @override
  EasyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EasyPageScrollPhysics(parent: buildParent(ancestor));
  }

  /// Lower velocity threshold = easier to fling to next page
  @override
  double get minFlingVelocity => 50.0; // default is ~365

  /// The page snaps based on PageScrollPhysics default behavior,
  /// but the lower minFlingVelocity means a gentle swipe triggers a page turn.

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 80, stiffness: 100, damping: 1.2);
}
