import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TopBar extends StatelessWidget {
  final double height;
  final String? label, image;
  final bool withBackButton;

  const TopBar({
    super.key,
    required this.height,
    this.withBackButton = true,
    this.label,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedUpperClipper(),
      child: Container(
        width: context.screenWidth,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD0A871), Color(0xFFB88E50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: image != null
              ? DecorationImage(
                  image: AssetImage(image!),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -.4),
                )
              : null,
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              if (label != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    width: context.screenWidth * .6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Text(
                      label!,
                      style: AppStyles.style42l.copyWith(
                        fontSize: (context.isLandscape || context.isTablet)
                            ? 30.sp
                            : null,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (withBackButton)
                Positioned(
                  left: 10.w,
                  top: 5.h,
                  child: IconButton(
                    onPressed: () {
                      context.pop();
                    },
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: context.isLandscape ? 18.w : 26.w,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvedUpperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    // Start from top left
    path.lineTo(0, 0);

    // Line to top right
    path.lineTo(size.width, 0);

    // Line down the right side to start of curve
    path.lineTo(size.width, size.height);

    // Create the upward curve at the bottom using quadratic bezier
    // The curve goes UP (concave)
    path.quadraticBezierTo(
      size.width / 2, // Control point X (center)
      size.height - 120.h, // Control point Y (curves upward)
      0, // End point X (left edge)
      size.height, // End point Y
    );

    // Close the path back to start
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
