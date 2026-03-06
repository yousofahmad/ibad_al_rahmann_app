import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import '../../../../core/helpers/extensions/screen_details.dart';
import '../../../../core/helpers/extensions/theme.dart';
import '../../bloc/quran/quran_cubit.dart';
import 'wbw_page_widget.dart';

class LandscapeQuranWidget extends StatefulWidget {
  const LandscapeQuranWidget({super.key});

  @override
  State<LandscapeQuranWidget> createState() => _LandscapeQuranWidgetState();
}

class _LandscapeQuranWidgetState extends State<LandscapeQuranWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<QuranCubit>();
      final currentPage = cubit.state.currentPage ?? 0;
      if (cubit.fullQuranController.hasClients) {
        cubit.fullQuranController.jumpToPage(currentPage);
      }
    });
    // Hide status bar in landscape for immersive reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Show status bar again when leaving landscape
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

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
          onPageChanged: (index) {
            context.read<QuranCubit>().onQuranPageChanged(index);
          },
          itemBuilder: (context, index) {
            return WbwPageWidget(pageNumber: index + 1, isZoomEnabled: true);
          },
        ),
      ),
    );
  }
}
