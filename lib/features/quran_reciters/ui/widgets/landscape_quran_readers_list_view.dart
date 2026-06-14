import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/widgets/top_bar_widget.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/ui/widgets/quran_readers_list_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/extensions/screen_details.dart';
import '../../data/models/reciter_model.dart';
import 'reciters_search_bar.dart';

class LandscapeReadersBody extends StatelessWidget {
  const LandscapeReadersBody({super.key, required this.reciters});
  final List<ReciterModel> reciters;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            AppAssets.imagesWhiteBackground,
            fit: BoxFit.cover,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: TopBar(height: 350.h, label: 'القـــراء'),
        ),
        Positioned.fill(
          top: 270.h,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: context.screenWidth * .6,
              child: const RecitersSearchBar(),
            ),
          ),
        ),
        Positioned.fill(
          top: 400.h,
          child: ReadersListView(reciters: reciters),
        ),
      ],
    );
    // return Container(
    //   decoration: const BoxDecoration(
    //     image: DecorationImage(
    //       fit: BoxFit.cover,
    //       image: AssetImage(AppAssets.imagesWhiteBackground),
    //     ),
    //   ),
    //   child: CustomScrollView(
    //     cacheExtent: 600,
    //     physics: const ClampingScrollPhysics(),
    //     slivers: [
    //       SliverToBoxAdapter(
    //         child: SizedBox(
    //           height: 280.h,
    //           child: Stack(
    //             children: [
    //               TopBar(
    //                 height: 242.h + context.topPadding,
    //                 label: 'القـــراء',
    //               ),
    //               Positioned.fill(
    //                 top:
    //                     (context.isTablet ? 180.h : 180.h) + context.topPadding,
    //                 child: const Align(
    //                   alignment: Alignment.topCenter,
    //                   child: RecitersSearchBar(),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ),
    //       const SliverToBoxAdapter(child: SizedBox(height: 20)),
    //       SliverPrototypeExtentList(
    //         prototypeItem: Padding(
    //           padding: const EdgeInsets.all(8.0),
    //           child: ReciterWidget(reciter: reciters[0]),
    //         ),
    //         delegate: SliverChildBuilderDelegate(
    //           childCount: reciters.length,
    //           (context, index) => Padding(
    //             padding: const EdgeInsets.only(bottom: 20),
    //             child: ReciterWidget(reciter: reciters[index]),
    //           ),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}
