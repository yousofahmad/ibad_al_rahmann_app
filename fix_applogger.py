import re

with open("lib/features/wird/ui/khatma_details_view.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    'AppLogger.log("Capturing page $realPage with key $key (current context $context)");',
    'AppLogger.log("ExportWird", "Capturing page $realPage with key $key (current context $context)");'
)
content = content.replace(
    'AppLogger.log("ERROR: key.currentContext is null for page $realPage!");',
    'AppLogger.log("ExportWird", "ERROR: key.currentContext is null for page $realPage!");'
)
content = content.replace(
    'AppLogger.log("Successfully captured page $realPage to ${paths.isNotEmpty ? paths.first : \'empty\'}");',
    'AppLogger.log("ExportWird", "Successfully captured page $realPage to ${paths.isNotEmpty ? paths.first : \'empty\'}");'
)
content = content.replace(
    'AppLogger.log(\'Error capturing page index $i: $e\');',
    'AppLogger.log("ExportWird", \'Error capturing page index $i: $e\');'
)

with open("lib/features/wird/ui/khatma_details_view.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed AppLogger syntax")
