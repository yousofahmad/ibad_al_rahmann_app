import re

with open('lib/features/wird/ui/isolated_wird_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'wird_completion_service.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';", "import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';\nimport 'package:ibad_al_rahmann/features/wird/services/wird_completion_service.dart';")

content = content.replace('''context.read<KhatmaCubit>().markWirdAsCompleted(widget.khatmaId!, widget.wirdIndex!);''', '''WirdCompletionService.complete(context: context, isKahfMode: widget.isKahfMode, isWirdMode: widget.isWirdMode, khatmaId: widget.khatmaId, wirdIndex: widget.wirdIndex);''')

with open('lib/features/wird/ui/isolated_wird_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
