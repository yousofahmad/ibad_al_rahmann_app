import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/reciter_model.dart';
import 'quran_readers_list_view.dart';
import 'reciters_search_bar.dart';

class LandscapeReadersBody extends StatelessWidget {
  const LandscapeReadersBody({super.key, required this.reciters});
  final List<ReciterAudioModel> reciters;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 8.h),
          child: const RecitersSearchBar(),
        ),
        Expanded(
          child: ReadersListView(reciters: reciters),
        ),
      ],
    );
  }
}
