import 'package:ibad_al_rahmann/core/networking/api_keys.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/di.dart';
import '../../../../core/networking/dio_consumer.dart';
import '../../../../core/services/prayer_times_cache.dart';
import '../models/user_location_model.dart';

class PrayerTimesRepo {
  Future<PrayerTimesResponseModel> getBasicPrayerTimes(
    UserLocationModel location,
  ) async {
    final now = DateTime.now();
    final dayKey = DateFormat('dd-MM-yyyy').format(now);
    var response = await getIt<DioConsumer>().get(
      '${ApiKeys.prayerTimesBaseUrl}/$dayKey',
      headers: {'content-type': 'application/json'},
      queryParameters: {
        'latitude': location.position.latitude.toString(),
        'longitude': location.position.longitude.toString(),
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    await cachePrayerTimes(
      data,
      latitude: location.position.latitude,
      longitude: location.position.longitude,
    );

    final model = PrayerTimesResponseModel.fromJson(data, location: location);

    return model;
  }

  Future<void> cachePrayerTimes(
    Map<String, dynamic> dataForDay, {
    required double latitude,
    required double longitude,
  }) async {
    final dayKey = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // Format coordinates to 4 decimal places for consistent cache keys
    final latStr = latitude.toStringAsFixed(4);
    final lngStr = longitude.toStringAsFixed(4);
    final cacheKey = '$dayKey|$latStr,$lngStr';
    await PrayerTimesCache.putEntry(cacheKey, {
      'timings': dataForDay['timings'],
      'date': dataForDay['date'],
    });
  }

  Future<PrayerTimesResponseModel?> getCachedPrayers({
    required UserLocationModel location,
  }) async {
    final todayKey = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // Format coordinates to 4 decimal places for consistent cache keys
    final latStr = location.position.latitude.toStringAsFixed(4);
    final lngStr = location.position.longitude.toStringAsFixed(4);
    final cacheKey = '$todayKey|$latStr,$lngStr';
    final cached = await PrayerTimesCache.getEntry(cacheKey);
    if (cached == null) return null;

    try {
      final timings = cached['timings'] as Map<String, dynamic>?;
      final date = cached['date'] as Map<String, dynamic>?;
      if (timings == null || date == null) return null;
      final modelJson = {'timings': timings, 'date': date};
      return PrayerTimesResponseModel.fromJson(modelJson, location: location);
    } catch (_) {
      return null;
    }
  }

  // Future<void> scheduleNotifications() async {
  //   final model = _lastFetched;
  //   if (model == null) return;

  //   final now = DateTime.now();
  //   final String ymd = DateFormat('yyyyMMdd').format(now);
  //   int baseId = int.parse(ymd) * 100; // Room for multiple notifications

  //   // Optionally clear previous ones for today (simple approach: cancel all)
  //   // If you prefer finer-grained control, track IDs you create and cancel those only.
  //   // await LocalNotificationService.instance.cancelAll();

  //   int i = 1;
  //   for (final pt in model.prayerTimes) {
  //     if (pt.date.isAfter(now)) {
  //       final id = baseId + i;
  //       final title = 'موعد صلاة ${pt.title}';
  //       final body =
  //           'حان وقت صلاة ${pt.title} في ${DateFormat('HH:mm').format(pt.date)}';
  //       await LocalNotificationService.instance.scheduleAt(
  //         id: id,
  //         title: title,
  //         body: body,
  //         dateTime: pt.date,
  //         androidChannelId: 'prayer_times_channel',
  //         androidChannelName: 'Prayer Times',
  //         androidChannelDescription: 'Prayer time reminders',
  //         androidImportance: Importance.max,
  //         androidPriority: Priority.high,
  //       );
  //     }

  //     // Optionally schedule iqama notification (uncomment if desired):
  //     // if (pt.iqamaDate.isAfter(now)) {
  //     //   final iqamaId = baseId + 50 + i;
  //     //   await LocalNotificationService.instance.scheduleAt(
  //     //     id: iqamaId,
  //     //     title: 'إقامة صلاة ${pt.title}',
  //     //     body: 'إقامة صلاة ${pt.title} عند ${DateFormat('HH:mm').format(pt.iqamaDate)}',
  //     //     dateTime: pt.iqamaDate,
  //     //     androidChannelId: 'prayer_times_channel',
  //     //     androidChannelName: 'Prayer Times',
  //     //     androidChannelDescription: 'Prayer time reminders',
  //     //     androidImportance: Importance.defaultImportance,
  //     //     androidPriority: Priority.defaultPriority,
  //     //   );
  //     // }

  //     i++;
  //   }
  // }
}
