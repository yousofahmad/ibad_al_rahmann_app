with open("lib/features/quran_audio/ui/widgets/surah_widget.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

# Insert import
if "quran_audio_download_service.dart" not in content:
    content = "import 'package:ibad_al_rahmann/features/quran_reciters/services/quran_audio_download_service.dart';\n" + content

# We want to replace `IconButton(...)` with a `Row` containing the Download button and the Play button.
target = r'''(IconButton\(\s*padding: EdgeInsets\.zero,\s*onPressed: \(\) \{\s*context\.read<QuranPlayerCubit>\(\)\.playSurah\(index\);\s*\},[\s\S]*?fit: BoxFit\.scaleDown,\s*\),\s*\),\s*\),)'''

replacement = r'''_DownloadButton(reciterId: context.read<QuranPlayerCubit>().reciter?.folderName ?? '', surahNumber: index),
              \1'''

content = re.sub(target, replacement, content)

download_button_code = '''
class _DownloadButton extends StatefulWidget {
  final String reciterId;
  final int surahNumber;
  const _DownloadButton({required this.reciterId, required this.surahNumber});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  @override
  void initState() {
    super.initState();
    QuranAudioDownloadService().checkState(widget.reciterId, widget.surahNumber);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reciterId.isEmpty) return const SizedBox();

    return AnimatedBuilder(
      animation: QuranAudioDownloadService(),
      builder: (context, child) {
        final state = QuranAudioDownloadService().getState(widget.reciterId, widget.surahNumber);
        final progress = QuranAudioDownloadService().getProgress(widget.reciterId, widget.surahNumber);

        if (state == AudioDownloadState.downloaded) {
          return IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () {
              QuranAudioDownloadService().deleteSurah(widget.reciterId, widget.surahNumber);
            },
          );
        } else if (state == AudioDownloadState.downloading) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2),
            ),
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.download, color: Colors.grey),
            onPressed: () {
              QuranAudioDownloadService().downloadSurah(widget.reciterId, widget.surahNumber);
            },
          );
        }
      },
    );
  }
}
'''

if "_DownloadButton" not in content:
    content += "\n" + download_button_code

with open("lib/features/quran_audio/ui/widgets/surah_widget.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Added DownloadButton to surah_widget")
