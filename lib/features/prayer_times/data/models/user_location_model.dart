import 'package:geolocator/geolocator.dart';

class UserLocationModel {
  final Position position;
  final String country, city;
  final String? address, arabicAddress;
  final String isoCode;

  UserLocationModel({
    required this.position,
    required this.arabicAddress,
    required this.address,
    required this.isoCode,
    required this.country,
    required this.city,
  });
}
