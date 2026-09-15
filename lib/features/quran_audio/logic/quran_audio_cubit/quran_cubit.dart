import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import '../../data/models/surah_audio_model.dart';
import '../../data/surah_list.dart';

part 'quran_state.dart';

class QuranAudioCubit extends Cubit<QuranState> {
  QuranAudioCubit(this.reciter) : super(QuranInitial());
  final ReciterAudioModel reciter;

  List<SurahAudioModel> quran = [];

  Future<List<SurahAudioModel>> getQuran([int? _]) async {
    emit(QuranLoading());
    try {
      final surahsMap = await ReciterAudioHelper.getSurahs(reciter);
      if (surahsMap.isNotEmpty) {
        quran = surahsMap.values.map((item) {
          final sName = (item.surahNumber >= 1 && item.surahNumber <= quranSurahs.length)
              ? quranSurahs[item.surahNumber - 1]
              : 'سورة ${item.surahNumber}';
          return SurahAudioModel(
            url: item.audioUrl,
            name: sName,
            surahNumber: item.surahNumber,
            durationSec: item.durationSec,
          );
        }).toList();

        quran.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
        emit(QuranSuccess());
        return quran;
      } else {
        // Fallback: generate default 114 surahs for reciter if config is still loading
        quran = List.generate(114, (index) {
          final sNum = index + 1;
          final sName = quranSurahs[index];
          return SurahAudioModel(
            url: 'https://audio-cdn.tarteel.ai/quran/surah/${reciter.folderName}/murattal/mp3/${sNum.toString().padLeft(3, '0')}.mp3',
            name: sName,
            surahNumber: sNum,
          );
        });
        emit(QuranSuccess());
        return quran;
      }
    } catch (e) {
      emit(QuranFailure(errMessage: 'تعذر جلب قائمة السور'));
      return [];
    }
  }
}

