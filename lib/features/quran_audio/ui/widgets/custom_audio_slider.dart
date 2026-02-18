import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';

class CustomAudioSlider extends StatefulWidget {
  const CustomAudioSlider({super.key});

  @override
  State<CustomAudioSlider> createState() => _CustomAudioSliderState();
}

class _CustomAudioSliderState extends State<CustomAudioSlider> {
  StreamSubscription? stream;
  late double max;
  Duration currentPosition = Duration.zero;

  void init() {
    max = getIt<AudioPlayer>().duration?.inSeconds.toDouble() ?? 1;

    stream = getIt<AudioPlayer>().createPositionStream().listen((val) {
      setState(() {
        currentPosition = val;
      });
    });
  }

  void seek(double value) {
    setState(() {
      getIt<AudioPlayer>().seek(Duration(seconds: value.toInt()));
    });
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  @override
  void dispose() {
    stream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          activeColor: Colors.white,
          min: 0,
          thumbColor: Colors.white,
          inactiveColor: const Color(0xff1d8f83),
          max: max,
          value: currentPosition.inSeconds.toDouble(),
          onChanged: seek,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                handlePosition(currentPosition),
                style: const TextStyle(
                  fontFamily: AppConsts.uthmanic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                handlePosition(getIt<AudioPlayer>().duration),
                style: const TextStyle(
                  fontFamily: AppConsts.uthmanic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String handlePosition(Duration? position) {
  if (position == null) {
    return '';
  }
  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final hours = twoDigits(position.inHours);
  final minutes = twoDigits(position.inMinutes.remainder(60));
  final seconds = twoDigits(position.inSeconds.remainder(60));

  final formatted = "$hours:$minutes:$seconds";

  // Map English digits to Arabic-Indic digits
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String toArabicNumbers(String input) {
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  return toArabicNumbers(formatted);
}
