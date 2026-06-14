import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AutoScrollControlOverlay extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const AutoScrollControlOverlay({
    super.key,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranCubit, QuranState>(
      builder: (context, state) {
        final cubit = context.read<QuranCubit>();

        // Use primary theme color (as in Wird)
        final themeColor = Theme.of(context).colorScheme.primary;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 320.w, // Match the width constraints
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      state.isAutoScrollPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (state.isAutoScrollPaused) {
                        onPlay();
                      } else {
                        cubit.setAutoScrollPaused(true);
                      }
                    },
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10.0,
                        ),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6.0,
                        ),
                      ),
                      child: Slider(
                        value: state.autoScrollSpeed,
                        min: 0.5,
                        max: 5.0,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                        onChanged: (val) {
                          cubit.setAutoScrollSpeed(val);
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onStop,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
