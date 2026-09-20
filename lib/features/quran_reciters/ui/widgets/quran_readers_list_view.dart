import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

import '../../data/models/reciter_model.dart';
import 'reciter_widget.dart';
import 'reciters_search_bar.dart';

class ReadersBody extends StatelessWidget {
  const ReadersBody({super.key, required this.reciters});
  final List<ReciterAudioModel> reciters;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: const RecitersSearchBar(),
        ),
        Expanded(
          child: ReadersListView(reciters: reciters),
        ),
      ],
    );
  }
}

class ReadersListView extends StatelessWidget {
  const ReadersListView({super.key, required this.reciters});

  final List<ReciterAudioModel> reciters;

  /// Build a flat list of mixed items: category headers + reciters.
  /// Each entry is either a String (header) or a ReciterAudioModel.
  List<Object> _buildFlatList() {
    // Preserve insertion order of categories as they appear in the list.
    final List<Object> items = [];
    String? currentCategory;
    for (final reciter in reciters) {
      if (reciter.category != currentCategory) {
        currentCategory = reciter.category;
        items.add(currentCategory);
      }
      items.add(reciter);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildFlatList();
    return CustomScrollView(
      cacheExtent: 600,
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: items.length,
            (context, index) {
              final item = items[index];
              if (item is String) {
                return _CategoryHeader(label: item);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ReciterWidget(reciter: item as ReciterAudioModel),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(28.w, 16.h, 28.w, 6.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFD0A871) : const Color(0xFF3E2723),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
