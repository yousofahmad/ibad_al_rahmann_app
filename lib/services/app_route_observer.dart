import 'package:flutter/material.dart';

/// Notifies route-aware screens when a pushed page is popped above them.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
