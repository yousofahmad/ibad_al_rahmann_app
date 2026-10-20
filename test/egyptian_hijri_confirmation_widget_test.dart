import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sync.dart';
import 'package:ibad_al_rahmann/widgets/egyptian_hijri_sync_status.dart';

void main() {
  final calendar = EgyptianHijriCalendar.instance;
  PendingHijriConfirmation seed() {
    SharedPreferences.setMockInitialValues({});
    calendar.resetForTesting();
    final today = EgyptianHijriSync.cairoToday();
    const survey = EgyptianHijriDate(hDay: 8, hMonth: 5, hYear: 1448);
    const dar = EgyptianHijriDate(hDay: 7, hMonth: 5, hYear: 1448);
    final pending = PendingHijriConfirmation(
      civilDate: today,
      displayedDate: survey,
      surveyDate: survey,
      darDate: dar,
      reason: 'sources_disagree',
    );
    calendar.replaceSnapshot({
      EgyptianHijriCalendar.civilKey(today): survey,
    }, pending: pending);
    return pending;
  }

  Future<void> mount(WidgetTester tester, {bool two = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const EgyptianHijriSyncStatus(),
              if (two) const EgyptianHijriSyncStatus(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final delta in [-1, 0, 1]) {
    testWidgets(
      'explicit confirmation adjustment $delta is saved, never silently Dar',
      (tester) async {
        final pending = seed();
        await mount(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('قيمة المساحة: ٨'), findsOneWidget);
        expect(find.textContaining('قيمة دار الإفتاء: ٧'), findsOneWidget);
        expect(calendar.lookup(pending.civilDate)?.hDay, 8);
        final prefix = delta == 0
            ? 'صحيح —'
            : (delta < 0 ? 'أقل بيوم —' : 'أكثر بيوم —');
        await tester.tap(find.textContaining(prefix));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(calendar.lookup(pending.civilDate)?.hDay, 8 + delta);
        expect(calendar.dateSourceLabel(pending.civilDate), 'بتأكيد المستخدم');
        final prefs = await SharedPreferences.getInstance();
        final saved = jsonDecode(
          prefs.getString(egyptianHijriConfirmationKey)!,
        );
        expect(saved['day'], 8 + delta);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Later preserves ESA and can be reopened manually without duplicate dialogs',
    (tester) async {
      final pending = seed();
      await mount(tester, two: true);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('لاحقًا'));
      await tester.pumpAndSettle();
      expect(calendar.shouldPromptConfirmation, isFalse);
      expect(calendar.lookup(pending.civilDate)?.hDay, 8);
      calendar.replaceSnapshot(calendar.surveyDates, pending: pending);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('تأكيد التاريخ').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('لاحقًا'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
