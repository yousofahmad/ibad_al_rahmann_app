import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/optional_mushaf_page_widget.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/selected_mushaf_page_widget.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/wbw_page_widget.dart';

void main() {
  test('dark paper is disabled only for the fixed-color tajweed format', () {
    expect(
      OptionalMushafPageWidget.shouldUseDarkPaper(
        darkTheme: true,
        hasTajweed: true,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.shouldUseDarkPaper(
        darkTheme: true,
        hasTajweed: false,
      ),
      isTrue,
    );
    expect(
      OptionalMushafPageWidget.shouldUseDarkPaper(
        darkTheme: false,
        hasTajweed: true,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.shouldForceLightPaper(
        darkTheme: true,
        hasTajweed: true,
      ),
      isTrue,
    );
    expect(
      OptionalMushafPageWidget.shouldForceLightPaper(
        darkTheme: true,
        hasTajweed: false,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.shouldForceLightPaper(
        darkTheme: false,
        hasTajweed: true,
      ),
      isFalse,
    );
  });

  test('empty format data is not considered a renderable cached page', () {
    expect(
      OptionalMushafPageWidget.canRenderFromCachedPage(
        hasLines: false,
        hasWords: true,
        fontLoaded: true,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.canRenderFromCachedPage(
        hasLines: true,
        hasWords: false,
        fontLoaded: true,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.canRenderFromCachedPage(
        hasLines: true,
        hasWords: true,
        fontLoaded: false,
      ),
      isFalse,
    );
    expect(
      OptionalMushafPageWidget.canRenderFromCachedPage(
        hasLines: true,
        hasWords: true,
        fontLoaded: true,
      ),
      isTrue,
    );
  });

  test(
    'selection factory keeps builtin renderer and isolates optional renderer',
    () {
      expect(
        SelectedMushafPageWidget.widgetTypeForSelection(true),
        WbwPageWidget,
      );
      expect(
        SelectedMushafPageWidget.widgetTypeForSelection(false),
        OptionalMushafPageWidget,
      );
    },
  );
}
