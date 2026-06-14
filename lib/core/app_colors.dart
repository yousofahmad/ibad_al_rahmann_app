import 'package:flutter/material.dart';

class AppColors {
  // Original Colors from flutter_quran_app-main
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const green = Color(0xff2fbaaf);

  static const lightGrey = Color.fromARGB(255, 235, 235, 222);
  static const lightYellow = Color(0xfff5eddf);
  static const greyYellow = Color(0xffc3c7b9);
  static const darkYellow = Color(0xff96895d);
  static const lime = Color(0xffacbd97);

  static const darkBrown = Color(0xff653811);

  static const darkGreen = Color(0xff212b0e);
  static const lightGreen = Color(0xff2c361b);
  static const greenShadow = Color(0xff1a240c);

  static const cyan = Color(0xff002928);
  static const darkCyan = Color(0xff002122);
  static const lightCyan = Color(0xff0b3333);
  static const outlineCyan = Color(0xff476366);

  static const red = Color(0xff290000);
  static const darkRed = Color(0xff210100);
  static const lightRed = Color(0xff330e0c);
  static const outlineRed = Color.fromARGB(255, 64, 25, 23);

  static const blue = Color(0xff162238);
  static const darkBlue = Color(0xff121b2e);
  static const lightBlue = Color(0xff202c42);
  static const outlineBlue = Color(0xff555f70);

  // Added Compatibility Colors
  static const Color primaryGold = Color(
    0xFFD0A871,
  ); // Preserved for other features
  static const Color lightGold = Color(0xFFFBD182);
  static const Color peach = Color(0xFFF5CD87);
  static const Color grey = Color(0xFF8E8D8B);
  static const Color transparent = Colors.transparent;
  static const Color white2 = Color(0xFFFFFFFF); // Pure white if needed

  static const Gradient goldGradient = LinearGradient(
    colors: [primaryGold, lightGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
