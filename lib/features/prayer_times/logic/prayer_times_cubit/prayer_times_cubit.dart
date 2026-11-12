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
      final savedLat =
          prefs.getDouble('last_lat') ?? prefs.getDouble('latitude');
      final savedLng =
          prefs.getDouble('last_lng') ?? prefs.getDouble('longitude');
      final savedTimestampMs = prefs.getInt('last_gps_update_ms');
      final DateTime? newerThan = savedTimestampMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedTimestampMs);

      final resolution = await PrayerLocationResolver.resolve(
        newerThan: newerThan,
        getCurrentFix: () async {
          final accessCheckStartedAt = DateTime.now();
          bool? serviceEnabled;
          LocationPermission? permission;
          try {
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
                'failure_reason': error is PrayerLocationAcquisitionException
                    ? error.reason
                    : null,
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
                'failure_reason': error is PrayerLocationAcquisitionException
                    ? error.reason
                    : null,
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
          'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
          'coordinates_logged': false,
        });
        return null;
      }

      final incomingTimestampMs = fix.timestamp?.millisecondsSinceEpoch;
      final latestSavedTimestampMs = prefs.getInt('last_gps_update_ms');
      if (incomingTimestampMs == null ||
          (latestSavedTimestampMs != null &&
              incomingTimestampMs <= latestSavedTimestampMs)) {
        final reason = incomingTimestampMs == null
            ? 'current_fix_timestamp_unavailable'
            : 'current_fix_not_newer_than_saved';
        AppLogger.logEvent('PrayerLocationRefresh', 'prayer_times_fix_failed', {
          'source': 'current_position_rejected',
          'current_failure': reason,
          'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
          'fix_age_ms': fix.timestamp == null
              ? null
              : DateTime.now().difference(fix.timestamp!).inMilliseconds,
          'coordinates_logged': false,
        });
        return null;
      }

      await prefs.setDouble('last_lat', fix.latitude);
      await prefs.setDouble('last_lng', fix.longitude);
      await prefs.setDouble('latitude', fix.latitude);
      await prefs.setDouble('longitude', fix.longitude);
      await prefs.setInt('last_gps_update_ms', incomingTimestampMs);

      final savedPlaceIsValid =
          savedLat != null &&
          savedLng != null &&
          savedLat.isFinite &&
          savedLng.isFinite &&
          savedLat >= -90 &&
          savedLat <= 90 &&
          savedLng >= -180 &&
          savedLng <= 180;
      final withinSavedPlaceArea =
          savedPlaceIsValid &&
          Geolocator.distanceBetween(
                savedLat,
                savedLng,
                fix.latitude,
                fix.longitude,
              ) <=
              250;
      String city = '';
      String country = '';
      String isoCode = '';
      if (withinSavedPlaceArea) {
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
