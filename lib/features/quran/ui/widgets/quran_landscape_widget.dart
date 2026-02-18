import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';

import '../../../../core/helpers/extensions/screen_details.dart';
import '../../../../core/helpers/extensions/theme.dart';
import '../../bloc/quran/quran_cubit.dart';
import 'full_page_rich_text_mobile.dart';

class LandscapeQuranWidget extends StatelessWidget {
  const LandscapeQuranWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: context.screenWidth,
        height: context.screenHeight,
        color: context.onPrimary,
        child: PageView.builder(
          controller: context.read<QuranCubit>().fullQuranController,
          itemCount: totalPagesCount,
          onPageChanged: null,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index > 1 ? 12 : 0),
              child: FullPageRichText(pageNumber: index + 1),
            );
          },
        ),
      ),
    );
  }
}
