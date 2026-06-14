import 'wird_model.dart';

class KhatmaModel {
  final String id;
  final String name;
  final List<WirdModel> wirds;
  final int currentWirdIndex;
  final String notificationType;
  final bool enableNotifications;
  final DateTime startDate;
  final int days;
  final int pagesPerWird;
  final String? dailyTime;
  final int notificationOffsetMinutes;

  /// For prayer-based khatmas: the prayer index (0=Fajr..4=Isha) at which the
  /// khatma was created. Used to offset the expected-index calculation so that
  /// starting on Asr (index 2) doesn't make the user appear 2 wirds behind.
  final int startPrayerOffset;

  KhatmaModel({
    required this.id,
    required this.name,
    required this.wirds,
    this.currentWirdIndex = 0,
    required this.notificationType,
    this.enableNotifications = true,
    required this.startDate,
    required this.days,
    this.pagesPerWird = 20,
    this.dailyTime,
    this.notificationOffsetMinutes = 30,
    this.startPrayerOffset = 0,
  });

  KhatmaModel copyWith({
    String? id,
    String? name,
    List<WirdModel>? wirds,
    int? currentWirdIndex,
    String? notificationType,
    bool? enableNotifications,
    DateTime? startDate,
    int? days,
    int? pagesPerWird,
    String? dailyTime,
    int? notificationOffsetMinutes,
    int? startPrayerOffset,
  }) {
    return KhatmaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      wirds: wirds ?? this.wirds,
      currentWirdIndex: currentWirdIndex ?? this.currentWirdIndex,
      notificationType: notificationType ?? this.notificationType,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      pagesPerWird: pagesPerWird ?? this.pagesPerWird,
      dailyTime: dailyTime ?? this.dailyTime,
      notificationOffsetMinutes: notificationOffsetMinutes ?? this.notificationOffsetMinutes,
      startPrayerOffset: startPrayerOffset ?? this.startPrayerOffset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'wirds': wirds.map((e) => e.toJson()).toList(),
      'currentWirdIndex': currentWirdIndex,
      'notificationType': notificationType,
      'enableNotifications': enableNotifications,
      'startDate': startDate.toIso8601String(),
      'days': days,
      'pagesPerWird': pagesPerWird,
      'dailyTime': dailyTime,
      'notificationOffsetMinutes': notificationOffsetMinutes,
      'startPrayerOffset': startPrayerOffset,
    };
  }

  factory KhatmaModel.fromJson(Map<String, dynamic> json) {
    return KhatmaModel(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'ختمة',
      wirds: (json['wirds'] as List).map((e) => WirdModel.fromJson(e)).toList(),
      currentWirdIndex: json['currentWirdIndex'] ?? 0,
      notificationType: json['notificationType'] as String? ?? 'daily',
      enableNotifications: json['enableNotifications'] ?? true,
      startDate: DateTime.parse(json['startDate']),
      days: json['days'] ?? 30,
      pagesPerWird: json['pagesPerWird'] ?? 20,
      dailyTime: json['dailyTime'],
      notificationOffsetMinutes: json['notificationOffsetMinutes'] ?? 30,
      startPrayerOffset: json['startPrayerOffset'] ?? 0,
    );
  }
}
