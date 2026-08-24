import 'package:flutter/physics.dart';

import 'package:flutter/material.dart';



class SensitivePageScrollPhysics extends ScrollPhysics {

  const SensitivePageScrollPhysics({super.parent});



  @override

  SensitivePageScrollPhysics applyTo(ScrollPhysics? ancestor) {

    return SensitivePageScrollPhysics(parent: buildParent(ancestor));

  }



  @override

  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {

    // If we're out of bounds and not stopping, use the standard behavior

    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||

        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {

      return super.createBallisticSimulation(position, velocity);

    }



    final Tolerance tolerance = toleranceFor(position);

    final double target = _getTargetPixels(position, tolerance, velocity);

    if (target != position.pixels) {

      return SpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);

    }

    return null;

  }



  @override

  bool get allowImplicitScrolling => false;



  double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {

    double page = position.pixels / position.viewportDimension;

    // Lower threshold means more sensitive flip. 0.2 means a 20% swipe will turn the page.

    double threshold = 0.2;

    

    // If swiping right/left with some velocity, adjust the page target

    if (velocity < -tolerance.velocity) {

      page -= threshold;

    } else if (velocity > tolerance.velocity) {

      page += threshold;

    }

    

    return page.roundToDouble() * position.viewportDimension;

  }

}

