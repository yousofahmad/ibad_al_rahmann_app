import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import '../../logic/quran_player/quran_player_cubit.dart';

class CustomAudioSlider extends StatefulWidget {
  const CustomAudioSlider({super.key});

  @override
  State<CustomAudioSlider> createState() => _CustomAudioSliderState();
}

class _CustomAudioSliderState extends State<CustomAudioSlider> {
  StreamSubscription? _posStream;
  StreamSubscription? _durStream;
  AudioPlayer? _player;
  late double max = 1;
  Duration currentPosition = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<QuranPlayerCubit>().player;
    if (_player != p) {
      _posStream?.cancel();
      _durStream?.cancel();
      _player = p;
      max = _player?.duration?.inSeconds.toDouble() ?? 1;

      _posStream = _player?.positionStream.listen((val) {
        if (!_isDragging && mounted) {
          setState(() {
            currentPosition = val;
          });
        }
      });

      _durStream = _player?.durationStream.listen((val) {
        if (val != null && mounted) {
          setState(() {
            max = val.inSeconds.toDouble() > 0 ? val.inSeconds.toDouble() : 1;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _durStream?.cancel();
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
          value: _isDragging
              ? _dragValue
              : (currentPosition.inSeconds.toDouble() > max
                    ? max
                    : currentPosition.inSeconds.toDouble()),
          onChanged: (val) {
            setState(() {
              _isDragging = true;
              _dragValue = val;
            });
          },
          onChangeEnd: (val) {
            _player?.seek(Duration(seconds: val.toInt()));
            setState(() {
              _isDragging = false;
            });
          },
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
                handlePosition(_player?.duration),
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
