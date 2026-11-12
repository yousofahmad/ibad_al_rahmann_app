import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/screens/more_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpMoreScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'enable_native_logging': true});
  await CacheHelper.init();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(430, 932),
      builder: (_, child) => const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MoreScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('يعرض المساعدة والدعم والتقرير الموحد وعن التطبيق منفصلًا', (
    tester,
  ) async {
    await _pumpMoreScreen(tester);

    final scrollable = find.byType(Scrollable).first;
    for (final title in [
      'المساعدة والدعم',
      'الإبلاغ عن مشكلة ومشاركة السجل',
      'عن التطبيق',
    ]) {
      final finder = find.text(title);
      await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
    }

    expect(find.text('مشاركة سجل التطبيق'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
