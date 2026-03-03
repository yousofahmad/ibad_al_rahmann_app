class CityProfile {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  String calculationMethod; // e.g., 'egypt', 'makkah'
  String madhab; // 'shafi', 'hanafi'
  Map<String, int> offsets; // 'Fajr': 0, ...

  CityProfile({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.calculationMethod = 'egypt',
    this.madhab = 'shafi',
    this.offsets = const {
      'Fajr': 0,
      'Sunrise': 0,
      'Dhuhr': 0,
      'Asr': 0,
      'Maghrib': 0,
      'Isha': 0,
    },
  });

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'calculationMethod': calculationMethod,
      'madhab': madhab,
      'offsets': offsets,
    };
  }

  factory CityProfile.fromJson(Map<String, dynamic> json) {
    return CityProfile(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      calculationMethod: json['calculationMethod'] ?? 'egypt',
      madhab: json['madhab'] ?? 'shafi',
      offsets: Map<String, int>.from(json['offsets'] ?? {}),
    );
  }

  CityProfile copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    String? madhab,
    Map<String, int>? offsets,
  }) {
    return CityProfile(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab,
      offsets: offsets ?? this.offsets,
    );
  }
}
