import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/user_location_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/services/prayer_location_resolver.dart';

import '../../data/repo/prayer_times_repo.dart';

part 'prayer_times_state.dart';

class PrayerTimesCubit extends Cubit<PrayerTimesState> {
  PrayerTimesCubit(this._repo) : super(PrayerTimesInitial()) {
    getPrayerTimes();
  }

  final PrayerTimesRepo _repo;

  PrayerTimesResponseModel? prayers;

  Future<UserLocationModel?> getUserLocation() async {
    final startedAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLat =
          prefs.getDouble('last_lat') ?? prefs.getDouble('latitude');
      final cachedLng =
          prefs.getDouble('last_lng') ?? prefs.getDouble('longitude');
      final cachedTimestampMs = prefs.getInt('last_gps_update_ms');
      final cachedFix =
          cachedLat != null &&
              cachedLng != null &&
              cachedLat.isFinite &&
              cachedLng.isFinite &&
              cachedLat >= -90 &&
              cachedLat <= 90 &&
              cachedLng >= -180 &&
              cachedLng <= 180
          ? PrayerLocationFix(
              latitude: cachedLat,
              longitude: cachedLng,
              timestamp: cachedTimestampMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(cachedTimestampMs),
            )
          : null;

      final resolution =
          await PrayerLocationResolver.resolve(
            cachedFix: cachedFix,
            getCurrentFix:
                () async {
                  final accessCheckStartedAt = DateTime.now();
                  bool? serviceEnabled;
                  LocationPermission? permission;
                  try {
                    serviceEnabled =
                        await Geolocator.isLocationServiceEnabled();
                    permission = await Geolocator.checkPermission();
                    if (!serviceEnabled) {
                      throw const PrayerLocationAcquisitionException(
                        'location_service_disabled',
                      );
                    }
                    if (permission == LocationPermission.denied ||
                        permission == LocationPermission.deniedForever) {
                      throw const PrayerLocationAcquisitionException(
                        'location_permission_unavailable',
                      );
                    }
                    AppLogger.logEvent(
                      'PrayerLocationRefresh',
                      'prayer_times_access_check_finished',
                      {
                        'duration_ms': DateTime.now()
                            .difference(accessCheckStartedAt)
                            .inMilliseconds,
                        'service_enabled': serviceEnabled,
                        'permission': permission.name,
                        'outcome': 'allowed',
                        'coordinates_logged': false,
                      },
                    );
                  } catch (error) {
                    AppLogger.logEvent(
                      'PrayerLocationRefresh',
                      'prayer_times_access_check_finished',
                      {
                        'duration_ms': DateTime.now()
                            .difference(accessCheckStartedAt)
                            .inMilliseconds,
                        'service_enabled': serviceEnabled,
                        'permission': permission?.name,
                        'outcome': 'failed',
                        'safe_failure_type': error.runtimeType.toString(),
                        'coordinates_logged': false,
                      },
                    );
                    rethrow;
                  }

                  const timeout = Duration(seconds: 6);
                  final fixStartedAt = DateTime.now();
                  AppLogger.logEvent(
                    'PrayerLocationRefresh',
                    'prayer_times_current_fix_started',
                    {
                      'accuracy': 'medium',
                      'timeout_ms': timeout.inMilliseconds,
                      'coordinates_logged': false,
                    },
                  );
                  try {
                    final position = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(
                        accuracy: LocationAccuracy.medium,
                        timeLimit: timeout,
                      ),
                    ).timeout(timeout);
                    AppLogger.logEvent(
                      'PrayerLocationRefresh',
                      'prayer_times_current_fix_finished',
                      {
                        'duration_ms': DateTime.now()
                            .difference(fixStartedAt)
                            .inMilliseconds,
                        'fix_age_ms': DateTime.now()
                            .difference(position.timestamp)
                            .inMilliseconds,
                        'accuracy_m': position.accuracy,
                        'outcome': 'success',
                        'coordinates_logged': false,
                      },
                    );
                    return PrayerLocationFix(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      timestamp: position.timestamp,
                      accuracy: position.accuracy,
                    );
                  } catch (error) {
                    AppLogger.logEvent(
                      'PrayerLocationRefresh',
                      'prayer_times_current_fix_finished',
                      {
                        'duration_ms': DateTime.now()
                            .difference(fixStartedAt)
                            .inMilliseconds,
                        'outcome': 'failed',
                        'safe_failure_type': error.runtimeType.toString(),
                        'coordinates_logged': false,
                      },
                    );
                    rethrow;
                  }
                },
            getLastKnownFix: () async {
              final lookupStartedAt = DateTime.now();
              AppLogger.logEvent(
                'PrayerLocationRefresh',
                'prayer_times_last_known_lookup_started',
                {'coordinates_logged': false},
              );
              try {
                final position = await Geolocator.getLastKnownPosition()
                    .timeout(const Duration(seconds: 1));
                AppLogger.logEvent(
                  'PrayerLocationRefresh',
                  'prayer_times_last_known_lookup_finished',
                  {
                    'duration_ms': DateTime.now()
                        .difference(lookupStartedAt)
                        .inMilliseconds,
                    'outcome': position == null ? 'empty' : 'success',
                    'fix_age_ms': position == null
                        ? null
                        : DateTime.now()
                              .difference(position.timestamp)
                              .inMilliseconds,
                    'coordinates_logged': false,
                  },
                );
                if (position == null) return null;
                return PrayerLocationFix(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  timestamp: position.timestamp,
                  accuracy: position.accuracy,
                );
              } catch (error) {
                AppLogger.logEvent(
                  'PrayerLocationRefresh',
                  'prayer_times_last_known_lookup_finished',
                  {
                    'duration_ms': DateTime.now()
                        .difference(lookupStartedAt)
                        .inMilliseconds,
                    'outcome': 'failed',
                    'safe_failure_type': error.runtimeType.toString(),
                    'coordinates_logged': false,
                  },
                );
                rethrow;
              }
            },
          );
      final fix = resolution.fix;
      if (fix == null) {
        AppLogger.logEvent('PrayerLocationRefresh', 'prayer_times_fix_failed', {
          'source': 'none',
          'current_failure': resolution.currentFailure,
          'last_known_failure': resolution.lastKnownFailure,
          'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
          'coordinates_logged': false,
        });
        return null;
      }

      await prefs.setDouble('last_lat', fix.latitude);
      await prefs.setDouble('last_lng', fix.longitude);
      await prefs.setDouble('latitude', fix.latitude);
      await prefs.setDouble('longitude', fix.longitude);
      final savedTimestampMs = prefs.getInt('last_gps_update_ms');
      final incomingTimestampMs = fix.timestamp?.millisecondsSinceEpoch;
      if (resolution.source != PrayerLocationFixSource.savedCoordinates &&
          incomingTimestampMs != null &&
          (savedTimestampMs == null ||
              incomingTimestampMs >= savedTimestampMs)) {
        await prefs.setInt('last_gps_update_ms', incomingTimestampMs);
      }

      final withinSavedPlaceArea =
          cachedFix != null &&
          Geolocator.distanceBetween(
                cachedFix.latitude,
                cachedFix.longitude,
                fix.latitude,
                fix.longitude,
              ) <=
              250;
      final useSavedPlaceName =
          resolution.source == PrayerLocationFixSource.savedCoordinates ||
          withinSavedPlaceArea;
      String city = '';
      String country = '';
      String isoCode = '';
      if (useSavedPlaceName) {
        city = prefs.getString('last_city_name') ?? '';
        country = prefs.getString('last_country_name') ?? '';
        isoCode = prefs.getString('last_iso_country_code') ?? '';
      } else {
        await prefs.remove('last_city_name');
        await prefs.remove('last_country_name');
        await prefs.remove('last_iso_country_code');
        unawaited(_updatePlaceNameForFix(fix, prefs));
      }

      AppLogger.logEvent('PrayerLocationRefresh', 'prayer_times_fix_resolved', {
        'source': resolution.source?.name,
        'current_failure': resolution.currentFailure,
        'last_known_failure': resolution.lastKnownFailure,
        'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'fix_age_ms': fix.timestamp == null
            ? null
            : DateTime.now().difference(fix.timestamp!).inMilliseconds,
        'coordinates_logged': false,
      });

      final position = Position(
        latitude: fix.latitude,
        longitude: fix.longitude,
        timestamp: fix.timestamp ?? DateTime.now(),
        accuracy: fix.accuracy ?? 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      return UserLocationModel(
        position: position,
        arabicAddress: city.isEmpty ? null : city,
        address: city.isEmpty ? null : city,
        country: country,
        city: city,
        isoCode: isoCode,
      );
    } catch (error) {
      AppLogger.logEvent('PrayerLocationRefresh', 'prayer_times_fix_failed', {
        'safe_failure_type': error.runtimeType.toString(),
        'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'coordinates_logged': false,
      });
      emit(
        PrayerTimesFailure(
          errMessage: 'عذرًا لا نستطيع تحديد مواعيد الصلاة في موقعك',
        ),
      );
    }
    return null;
  }

  Future<void> _updatePlaceNameForFix(
    PrayerLocationFix fix,
    SharedPreferences prefs,
  ) async {
    final startedAt = DateTime.now();
    try {
      final placemarks = await placemarkFromCoordinates(
        fix.latitude,
        fix.longitude,
      ).timeout(const Duration(seconds: 5));
      if (placemarks.isEmpty) return;

      final currentLat = prefs.getDouble('last_lat');
      final currentLng = prefs.getDouble('last_lng');
      if (currentLat == null ||
          currentLng == null ||
          Geolocator.distanceBetween(
                currentLat,
                currentLng,
                fix.latitude,
                fix.longitude,
              ) >
              250) {
        AppLogger.logEvent(
          'PrayerLocationRefresh',
          'prayer_times_reverse_geocoding_discarded',
          {'reason': 'location_changed_before_lookup_finished'},
        );
        return;
      }

      final place = placemarks.first;
      final city = place.locality?.isNotEmpty == true
          ? place.locality
          : place.subAdministrativeArea;
      if (city != null && city.isNotEmpty) {
        await prefs.setString('last_city_name', city);
      }
      if (place.country?.isNotEmpty == true) {
        await prefs.setString('last_country_name', place.country!);
      }
      if (place.isoCountryCode?.isNotEmpty == true) {
        await prefs.setString('last_iso_country_code', place.isoCountryCode!);
      }
      AppLogger.logEvent(
        'PrayerLocationRefresh',
        'prayer_times_reverse_geocoding_finished',
        {
          'outcome': 'success',
          'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
          'coordinates_logged': false,
        },
      );
    } catch (error) {
      AppLogger.logEvent(
        'PrayerLocationRefresh',
        'prayer_times_reverse_geocoding_finished',
        {
          'outcome': 'failed',
          'safe_failure_type': error.runtimeType.toString(),
          'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
          'coordinates_logged': false,
        },
      );
    }
  }

  Future<void> getPrayerTimes() async {
    emit(PrayerTimesLoading());

    UserLocationModel? location = await getUserLocation();

    if (location == null) {
      emit(
        PrayerTimesFailure(
          errMessage: 'عذرًا لا نستطيع تحديد مواعيد الصلاة في موقعك',
        ),
      );
      return;
    }

    prayers = await _repo.getCachedPrayers(location: location);

    if (prayers != null) {
      emit(PrayerTimesSuccess());
      return;
    }

    try {
      prayers = await _repo.getBasicPrayerTimes(location);
      emit(PrayerTimesSuccess());
    } catch (e) {
      emit(
        PrayerTimesFailure(
          errMessage:
              ' حدث خطأ ما يرجى التأكد من الاتصال بالانترنت: ${e.toString()}',
        ),
      );
    }
  }
}
