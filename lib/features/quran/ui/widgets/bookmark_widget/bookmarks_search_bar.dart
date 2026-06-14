import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookmarksSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const BookmarksSearchBar({
    super.key,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = Theme.of(context).primaryColor;
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(25.r),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14.sp, color: textColor),
        decoration: InputDecoration(
          hintText: 'ابحث في المحفوظات...',
          hintStyle: TextStyle(fontSize: 14.sp, color: hintColor),
          prefixIcon: Icon(Icons.search, size: 20.w, color: iconColor),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              return value.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        controller.clear();
                        onClear();
                      },
                      icon: Icon(Icons.clear, size: 20.w, color: iconColor),
                    )
                  : const SizedBox.shrink();
            },
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }
}
