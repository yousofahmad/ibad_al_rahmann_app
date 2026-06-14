import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:ibad_al_rahmann/features/prayer_times/data/models/user_location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repo/prayer_times_repo.dart';

part 'prayer_times_state.dart';

class PrayerTimesCubit extends Cubit<PrayerTimesState> {
  PrayerTimesCubit(this._repo) : super(PrayerTimesInitial()) {
    getPrayerTimes();
  }

  final PrayerTimesRepo _repo;

  PrayerTimesResponseModel? prayers;

  Future<UserLocationModel?> getUserLocation() async {
    try {
      await GeocodingPlatform.instance!.setLocaleIdentifier('en');

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      await GeocodingPlatform.instance!.setLocaleIdentifier('ar');

      List<Placemark> arabicPlacemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks.last;
      String? address = place.street;

      if (place.isoCountryCode == 'EG') {
        address =
            '${place.administrativeArea ?? place.locality}, ${place.country}';
      } else if (place.isoCountryCode == 'SA') {
        address =
            '${place.subAdministrativeArea ?? place.locality}, ${place.administrativeArea ?? place.locality}, ${place.country}';
      }

      String? arabicAddress = arabicPlacemarks.last.street;
      if (arabicAddress == null || arabicAddress.isEmpty) {
        if (arabicPlacemarks.last.country != null &&
            arabicPlacemarks.last.locality != null) {
          arabicAddress =
              '${arabicPlacemarks.last.country} - ${arabicPlacemarks.last.locality}';
        }
      }

      return UserLocationModel(
        position: position,
        arabicAddress: arabicAddress,
        address: address,
        country: place.country!,
        city: place.administrativeArea ?? place.locality!,
        isoCode: place.isoCountryCode!,
      );
    } catch (e) {
      emit(
        PrayerTimesFailure(
          errMessage: 'عذرًا لا نستطيع تحديد مواعيد الصلاة في موقعك',
        ),
      );
    }
    return null;
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
