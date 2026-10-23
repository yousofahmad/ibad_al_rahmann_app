import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/screens/app_features_guide_screen.dart';

Future<void> _pumpGuide(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(430, 932),
      builder: (_, child) => MaterialApp(
        themeMode: mode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AppFeaturesGuideScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('يعرض الميزات المضافة عبر البحث بلا إيموجي', (tester) async {
    await _pumpGuide(tester);
    for (final title in [
      'لوحة رمضان وتنبيهات العيد',
      'متابعة قضاء الصيام والصلوات',
      'الرقية الشرعية من النصوص المضمنة',
      'تخصيص تنبيهات الأذان والصلاة',
      'التاريخ الهجري المصري ومراجعة المصدر',
      'إدارة مدن متعددة لمواقيت الصلاة',
    ]) {
      await tester.enterText(find.byType(TextField), title);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.data ?? '',
          isNot(contains(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true))),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('يصفّي البحث ويعرض الحالة بلا نتائج', (tester) async {
    await _pumpGuide(tester);
    await tester.enterText(find.byType(TextField), 'رمضان');
    await tester.pumpAndSettle();
    expect(find.text('لوحة رمضان وتنبيهات العيد'), findsOneWidget);
    expect(find.text('إدارة مدن متعددة لمواقيت الصلاة'), findsNothing);
    await tester.enterText(find.byType(TextField), 'لا توجد ميزة بهذا الاسم');
    await tester.pumpAndSettle();
    expect(find.textContaining('لم يتم العثور'), findsOneWidget);
  });

  testWidgets('يعمل تصنيف المدن واتجاه RTL والثيم الداكن', (tester) async {
    await _pumpGuide(tester, mode: ThemeMode.dark);
    final category = find.text('المدن والمواقع');
    expect(category, findsOneWidget);
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(find.text('إدارة مدن متعددة لمواقيت الصلاة'), findsOneWidget);
    expect(find.text('لوحة رمضان وتنبيهات العيد'), findsNothing);
    final context = tester.element(find.byType(AppFeaturesGuideScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
