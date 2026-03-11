import 'wird_model.dart';

class KhatmaModel {
  final String id;
  final String name;
  final List<WirdModel> wirds;
  final int currentWirdIndex;
  final String notificationType; // 'none', 'daily', 'prayer'
  final DateTime startDate;
  final int days;
  final int pagesPerWird; // pages per day (computed from quantity selector)
  final String? dailyTime; // HH:mm format

  KhatmaModel({
    required this.id,
    required this.name,
    required this.wirds,
    this.currentWirdIndex = 0,
    required this.notificationType,
    required this.startDate,
    required this.days,
    this.pagesPerWird = 20,
    this.dailyTime,
  });

  KhatmaModel copyWith({
    String? id,
    String? name,
    List<WirdModel>? wirds,
    int? currentWirdIndex,
    String? notificationType,
    DateTime? startDate,
    int? days,
    int? pagesPerWird,
    String? dailyTime,
  }) {
    return KhatmaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      wirds: wirds ?? this.wirds,
      currentWirdIndex: currentWirdIndex ?? this.currentWirdIndex,
      notificationType: notificationType ?? this.notificationType,
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      pagesPerWird: pagesPerWird ?? this.pagesPerWird,
      dailyTime: dailyTime ?? this.dailyTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'wirds': wirds.map((e) => e.toJson()).toList(),
      'currentWirdIndex': currentWirdIndex,
      'notificationType': notificationType,
      'startDate': startDate.toIso8601String(),
      'days': days,
      'pagesPerWird': pagesPerWird,
      'dailyTime': dailyTime,
    };
  }

  factory KhatmaModel.fromJson(Map<String, dynamic> json) {
    return KhatmaModel(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'ختمة',
      wirds: (json['wirds'] as List).map((e) => WirdModel.fromJson(e)).toList(),
      currentWirdIndex: json['currentWirdIndex'] ?? 0,
      notificationType: json['notificationType'],
      startDate: DateTime.parse(json['startDate']),
      days: json['days'] ?? 30,
      pagesPerWird: json['pagesPerWird'] ?? 20,
      dailyTime: json['dailyTime'],
    );
  }
}
