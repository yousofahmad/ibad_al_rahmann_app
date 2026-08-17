import subprocess
import os

files_to_restore = [
    'lib/core/app_constants.dart',
    'lib/features/prayer_times/ui/widgets/mobile_prayer_time_widget.dart',
    'lib/features/prayer_times/ui/widgets/prayer_times_screen_body_builder.dart',
    'lib/features/prayer_times/ui/widgets/tablet_prayer_time_widget.dart',
    'lib/features/quran/data/models/searching_surah_model.dart',
    'lib/features/quran/ui/widgets/components/page_details.dart',
    'lib/features/quran_audio/data/surah_list.dart',
    'lib/features/quran_audio/logic/quran_audio_cubit/quran_cubit.dart',
    'lib/features/quran_audio/logic/quran_player/quran_player_cubit.dart',
    'lib/features/quran_audio/ui/widgets/quran_screen_bottom_sheet.dart',
    'lib/features/quran_reciters/data/models/reciter_model.dart',
    'lib/quran_app.dart',
    'lib/repositories/muezzin_repository.dart',
    'lib/screens/azkar_statistics_screen.dart',
    'lib/screens/bubble_screen.dart',
    'lib/widgets/service_card.dart'
]

for file_path in files_to_restore:
    try:
        # Get content from ea8daad
        cmd = f'git show ea8daad:{file_path}'
        raw_bytes = subprocess.check_output(cmd, shell=True)
        # Decode as utf-8 (ignoring or stripping BOM)
        text = raw_bytes.decode('utf-8-sig')
        # Write back to file cleanly as UTF-8
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f'Successfully restored: {file_path}')
    except Exception as e:
        print(f'Error restoring {file_path}: {e}')
