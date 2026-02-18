import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum NavigationDirection { rightToLeft, leftToRight, upToDown, downToUp }

extension AppNavigator on BuildContext {
  void pop({List? result}) => Navigator.pop(this, result);

  bool get canPop => Navigator.canPop(this);

  void push(Widget screen, {NavigationDirection? direction}) {
    if (Platform.isIOS) {
      Navigator.of(this).push(MaterialPageRoute(builder: (_) => screen));
    } else {
      Navigator.push(
        this,
        MyCustomRoute(
          screen: screen,
          direction: direction ?? NavigationDirection.rightToLeft,
        ),
      );
    }
  }

  void pushReplacement(Widget screen, {NavigationDirection? direction}) {
    if (Platform.isIOS) {
      Navigator.of(this).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      Navigator.pushReplacement(
        this,
        Platform.isIOS
            ? CupertinoPageRoute(builder: (_) => screen)
            : MyCustomRoute(
                screen: screen,
                direction: direction ?? NavigationDirection.rightToLeft,
              ),
      );
    }
  }

  void pushAndRemoveUntil(Widget screen, {NavigationDirection? direction}) {
    if (Platform.isIOS) {
      Navigator.of(this).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => screen),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        this,
        MyCustomRoute(
          screen: screen,
          direction: direction ?? NavigationDirection.rightToLeft,
        ),
        (route) => false,
      );
    }
  }
}

class MyCustomRoute extends PageRouteBuilder {
  final Widget screen;
  final NavigationDirection direction;
  MyCustomRoute({required this.screen, required this.direction})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = const Offset(1, 0);
            if (direction == NavigationDirection.upToDown) {
              begin = const Offset(0, -1);
            } else if (direction == NavigationDirection.downToUp) {
              begin = const Offset(0, 1);
            } else if (direction == NavigationDirection.leftToRight) {
              begin = const Offset(-1, 0);
            }
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(position: offsetAnimation, child: child);
          },
        );
}
