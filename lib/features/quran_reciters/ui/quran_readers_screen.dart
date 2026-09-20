import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/logic/quran_readers_cubit.dart';

import 'widgets/quran_readers_screen_body.dart';

class QuranReadersScreen extends StatelessWidget {
  const QuranReadersScreen({super.key, this.paperColor});
  final Color? paperColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? Colors.black : const Color(0xFFFFF9E5);
    final primaryColor = isDark ? const Color(0xFFD0A871) : const Color(0xFF1B4D3E);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: paperColor ?? defaultBg,
      appBar: AppBar(
        title: Text(
          'القــرّاء',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF1B4D3E),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocProvider(
        create: (context) => QuranReadersCubit(),
        child: const QuranReadersScreenBody(),
      ),
    );
  }
}
