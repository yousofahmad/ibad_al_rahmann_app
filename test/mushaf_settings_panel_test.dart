import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/mushaf_settings_panel.dart';

void main() {
  testWidgets('shows two RTL options and invokes independent callbacks', (
    tester,
  ) async {
    final selections = <String>[];
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(primaryColor: const Color(0xFFD0A871)),
        home: Scaffold(
          body: MushafSettingsPanel(onSelectionChanged: selections.add),
        ),
      ),
    );

    expect(find.text('الألوان'), findsOneWidget);
    expect(find.text('تنسيقات المصحف'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('الألوان'));
    await tester.tap(find.text('تنسيقات المصحف'));
    expect(selections, ['colors', 'format']);
    expect(tester.takeException(), isNull);
  });
}
