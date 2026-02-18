import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions/screen_details.dart';
import '../../bloc/quran/quran_cubit.dart';
import '../layouts/min_quran_widget.dart';
import '../widgets/full_quran_mobile.dart';
import '../widgets/verse_player.dart';
import 'quran_landscape_widget.dart';

class QuranScreenBody extends StatelessWidget {
  const QuranScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (context.isLandscape) const LandscapeQuranWidget(),
        if (!context.isLandscape)
          SafeArea(
            top: true,
            left: false,
            right: false,
            bottom: true,
            child: BlocBuilder<QuranCubit, QuranState>(
              buildWhen: (previous, current) {
                return previous.layout != current.layout ||
                    previous.currentPage != current.currentPage;
              },
              builder: (context, state) {
                switch (state.layout) {
                  case QuranLayout.full:
                    return FullQuranWidget(currentPage: state.currentPage);
                  case QuranLayout.min:
                    return MinQuranWidget(currentPage: state.currentPage);
                }
              },
            ),
          ),
        const Positioned.fill(
          child: Align(alignment: Alignment.bottomCenter, child: VersePlayer()),
        ),
      ],
    );
  }
}
