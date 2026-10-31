import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/wird/services/wird_completion_service.dart';
import 'package:ibad_al_rahmann/services/app_route_observer.dart';

void main() {
  group('Wird completion accountability mapping', () {
    test('a khatma started at Maghrib maps its first wird to Maghrib', () {
      expect(
        WirdCompletionService.prayerNameForWird(
          wirdIndex: 0,
          startPrayerOffset: 3,
        ),
        'المغرب',
      );
    });

    test('prayer mapping wraps to the next day after Isha', () {
      expect(
        WirdCompletionService.prayerNameForWird(
          wirdIndex: 3,
          startPrayerOffset: 4,
        ),
        'العصر',
      );
    });

    test('a khatma started at Fajr keeps its original index mapping', () {
      expect(WirdCompletionService.prayerNameForWird(wirdIndex: 3), 'المغرب');
    });

    test('saves the visible prayer-based accountability item key', () {
      expect(
        WirdCompletionService.accountabilityKeyForWird(
          label: 'ختمة القرآن',
          notificationType: 'prayer',
          wirdIndex: 0,
          startPrayerOffset: 3,
        ),
        'ختمة القرآن - المغرب',
      );
    });

    test(
      'legacy empty labels use the same fallback as the accountability UI',
      () {
        expect(
          WirdCompletionService.accountabilityKeyForWird(
            label: '',
            notificationType: 'prayer',
            wirdIndex: 0,
            startPrayerOffset: 3,
          ),
          'ورد التلاوة - المغرب',
        );
      },
    );
  });

  testWidgets('the app route observer notifies a covered screen on return', (
    tester,
  ) async {
    final observer = appRouteObserver;
    var returnedToCoveredRoute = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: _RouteAwarePage(onReturned: () => returnedToCoveredRoute = true),
        routes: {
          '/reader': (context) => Scaffold(
            body: Column(
              children: [
                const Text('قارئ الورد'),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('عودة'),
                ),
              ],
            ),
          ),
        },
      ),
    );

    await tester.tap(find.text('افتح القارئ'));
    await tester.pumpAndSettle();
    expect(find.text('قارئ الورد'), findsOneWidget);

    await tester.tap(find.text('عودة'));
    await tester.pumpAndSettle();
    expect(returnedToCoveredRoute, isTrue);
  });
}

class _RouteAwarePage extends StatefulWidget {
  const _RouteAwarePage({required this.onReturned});

  final VoidCallback onReturned;

  @override
  State<_RouteAwarePage> createState() => _RouteAwarePageState();
}

class _RouteAwarePageState extends State<_RouteAwarePage> with RouteAware {
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => widget.onReturned();

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pushNamed('/reader'),
        child: const Text('افتح القارئ'),
      ),
    ),
  );
}
