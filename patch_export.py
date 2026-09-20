import re

with open("lib/features/wird/ui/khatma_details_view.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = """    for (int i = 0; i < _totalPages; i++) {
      try {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(i);
        }

        // Wait for font decoding, layout, and repaint to fully stabilize
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final realPage = widget.startPage + i;
        final key = cubit.getPageKey(realPage);

        // Rule 3: Explicit Extension
        final fileName = 'wird_page_$realPage.png';

        // Rule 1: Sequential Loop (standard for loop)
        final paths = await ShareHelper.captureMultiplePages(
          keys: [key],
          fileNames: [fileName],
          quality: widget.quality,
        );
        capturedPaths.addAll(paths);
      } catch (e) {
        // Rule 4: Graceful Error Handling (Log and continue)
        debugPrint('Error capturing page index $i: $e');
      }

      widget.onProgress(i + 1, _totalPages);
    }"""

replacement = """    for (int i = 0; i < _totalPages; i++) {
      try {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(i);
        }

        // Wait for font decoding, layout, and repaint to fully stabilize
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final realPage = widget.startPage + i;
        final key = cubit.getPageKey(realPage);
        
        AppLogger.log("Capturing page $realPage with key $key (current context $context)");

        if (key.currentContext == null) {
          AppLogger.log("ERROR: key.currentContext is null for page $realPage!");
        }

        // Rule 3: Explicit Extension
        final fileName = 'wird_page_$realPage.png';

        // Rule 1: Sequential Loop (standard for loop)
        final paths = await ShareHelper.captureMultiplePages(
          keys: [key],
          fileNames: [fileName],
          quality: widget.quality,
        );
        capturedPaths.addAll(paths);
        
        AppLogger.log("Successfully captured page $realPage to ${paths.isNotEmpty ? paths.first : 'empty'}");
      } catch (e) {
        // Rule 4: Graceful Error Handling (Log and continue)
        AppLogger.log('Error capturing page index $i: $e');
      }

      widget.onProgress(i + 1, _totalPages);
    }"""

if target in content:
    content = content.replace(target, replacement)
    with open("lib/features/wird/ui/khatma_details_view.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target not found")
