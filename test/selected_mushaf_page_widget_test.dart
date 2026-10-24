import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/optional_mushaf_page_widget.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/selected_mushaf_page_widget.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/core/wbw_page_widget.dart';

void main() {
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
