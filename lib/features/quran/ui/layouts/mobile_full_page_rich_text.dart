import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/fonts_helper.dart';
import '../widgets/wbw_page_widget.dart';

class MobileFullPageRichText extends StatefulWidget {
  const MobileFullPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MobileFullPageRichText> createState() => _MobileFullPageRichTextState();
}

class _MobileFullPageRichTextState extends State<MobileFullPageRichText> {
  String? currentFontFamily;

  Future<void> _changeFont() async {
    String family = FontsHelper.getFontFamily(widget.pageNumber);
    await FontsHelper.loadFont(
      family,
      FontsHelper.getFontPath(widget.pageNumber),
    );
    setState(() {
      currentFontFamily = family;
    });
  }

  @override
  void initState() {
    _changeFont();
    super.initState();
  }

  double getFontSize() {
    final n = widget.pageNumber;
    // if(context.isLandscape){
    //   return 19.sp;
    // }
    if (n <= 2) {
      return 26.sp;
    } else if (n == 574 || n == 579 || n == 585) {
      return 21.9.sp;
    } else if (n == 566 || n == 600 || n == 593) {
      return 22.1.sp;
    } else if (n == 567 ||
        n == 568 ||
        n == 569 ||
        n == 576 ||
        n == 592 ||
        n == 589 ||
        n == 590) {
      return 21.8.sp;
    } else if (n == 69 || n == 70) {
      return 22.7.sp;
    } else if (n == 145 ||
        n == 8 ||
        n == 33 ||
        n == 238 ||
        n == 240 ||
        n == 243 ||
        n == 509 ||
        n == 32 ||
        n == 38) {
      return 22.6.sp;
    } else if (n == 532 || n == 53 || n == 58) {
      return 22.5.sp;
    } else if (n == 241 || n == 11 || n == 17 || n == 19) {
      return 22.4.sp;
    } else if (n == 577 || n == 578 || n == 583) {
      return 21.35.sp;
    } else {
      return 22.28.sp;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentFontFamily == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 6.w,
            right: 6.w,
            top: 4.h,
            bottom: 2.h,
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: WbwPageWidget(pageNumber: widget.pageNumber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// class QuranFullPage2 extends StatefulWidget {
//   final int pageNumber;
//   final String currentFontFamily;
//   final double fontSize;

//   const QuranFullPage2({
//     Key? key,
//     required this.pageNumber,
//     required this.currentFontFamily,
//     required this.fontSize,
//   }) : super(key: key);

//   @override
//   State<QuranFullPage2> createState() => _QuranFullPage2State();
// }

// class _QuranFullPage2State extends State<QuranFullPage2> {
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Align(
//           alignment: Alignment.centerRight,
//           child: Container(
//             decoration: const BoxDecoration(
//                 // border: Border(right: BorderSide(color: Colors.black)),
//                 ),
//             child: Image.asset(
//               AppAssets.imagesFullPage2,
//               alignment: Alignment.centerRight,
//               width: context.screenWidth * 1.2,
//               height: context.screenHeight,
//             ),
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             children: [
//               Expanded(
//                 child: Center(
//                   child: SingleChildScrollView(
//                     child: MobileSurahVersesWidget(
//                       isFullPage: true,
//                       family: widget.currentFontFamily,
//                       fontSize: widget.fontSize,
//                       pageNumber: widget.pageNumber,
//                     ),
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.symmetric(vertical: 12.h),
//                 child: Text(
//                   widget.pageNumber.toArabicNums,
//                   style: context.titleSmall,
//                 ),
//               ),
//             ],
//           ),
//         )
//       ],
//     );
//   }
// }

// class QuranFullPage1 extends StatefulWidget {
//   final int pageNumber;
//   final String currentFontFamily;
//   final double fontSize;

//   const QuranFullPage1({
//     Key? key,
//     required this.pageNumber,
//     required this.currentFontFamily,
//     required this.fontSize,
//   }) : super(key: key);

//   @override
//   State<QuranFullPage1> createState() => _QuranFullPage1State();
// }

// class _QuranFullPage1State extends State<QuranFullPage1> {
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Align(
//           alignment: Alignment.centerLeft,
//           child: Container(
//             decoration: const BoxDecoration(
//               border: Border(right: BorderSide(color: Colors.red)),
//             ),
//             // padding: EdgeInsets.only(right: widget.pageNumber == 1 ? 12 : 0),
//             child: Image.asset(
//               AppAssets.imagesFullPage1,
//               alignment: Alignment.centerLeft,
//               width: context.screenWidth * 1.2,
//               height: context.screenHeight,
//             ),
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             children: [
//               Expanded(
//                 child: Center(
//                   child: SingleChildScrollView(
//                     child: MobileSurahVersesWidget(
//                       isFullPage: true,
//                       family: widget.currentFontFamily,
//                       fontSize: widget.fontSize,
//                       pageNumber: widget.pageNumber,
//                     ),
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: EdgeInsets.symmetric(vertical: 12.h),
//                 child: Text(
//                   widget.pageNumber.toArabicNums,
//                   style: context.titleSmall,
//                 ),
//               ),
//             ],
//           ),
//         )
//       ],
//     );
//   }
// }
