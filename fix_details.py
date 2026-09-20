import re

with open('lib/features/wird/ui/khatma_details_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'wird_completion_service.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';", "import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';\nimport 'package:ibad_al_rahmann/features/wird/services/wird_completion_service.dart';")

# Replace call
content = content.replace('''                              context.read<KhatmaCubit>().markWirdAsCompleted(
                                khatma.id,
                                currentWirdIndex,
                              );''', '''                              WirdCompletionService.complete(
                                context: context,
                                isWirdMode: true,
                                khatmaId: khatma.id,
                                wirdIndex: currentWirdIndex,
                              );''')

with open('lib/features/wird/ui/khatma_details_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
