import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/wbw_page_widget.dart';

class TabletMinPageRichText extends StatefulWidget {
  const TabletMinPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<TabletMinPageRichText> createState() => _TabletMinPageRichTextState();
}

class _TabletMinPageRichTextState extends State<TabletMinPageRichText> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Column(
        crossAxisAlignment: widget.pageNumber <= 2
            ? CrossAxisAlignment.center
            : widget.pageNumber.isEven
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.sizeOf(context).width *
                    (widget.pageNumber == 1 ? 0.08 : 0.04),
              ),
              child: WbwPageWidget(pageNumber: widget.pageNumber),
            ),
          ),
          if (widget.pageNumber <= 2)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Text(
                widget.pageNumber.toArabicNums,
                style: context.titleSmall.copyWith(fontSize: 16.sp),
              ),
            ),
        ],
      ),
    );
  }
}
