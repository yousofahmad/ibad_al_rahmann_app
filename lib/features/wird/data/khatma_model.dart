import 'wird_model.dart';

class KhatmaModel {
  final List<WirdModel> wirds;
  final int currentWirdIndex;
  final String notificationType; // 'none', 'daily', 'prayer'
  final DateTime startDate;
  final int days;
  final int pagesPerWird; // pages per day (computed from quantity selector)

  KhatmaModel({
    required this.wirds,
    this.currentWirdIndex = 0,
    required this.notificationType,
    required this.startDate,
    required this.days,
    this.pagesPerWird = 20,
  });

  KhatmaModel copyWith({
    List<WirdModel>? wirds,
    int? currentWirdIndex,
    String? notificationType,
    DateTime? startDate,
    int? days,
    int? pagesPerWird,
  }) {
    return KhatmaModel(
      wirds: wirds ?? this.wirds,
      currentWirdIndex: currentWirdIndex ?? this.currentWirdIndex,
      notificationType: notificationType ?? this.notificationType,
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      pagesPerWird: pagesPerWird ?? this.pagesPerWird,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wirds': wirds.map((e) => e.toJson()).toList(),
      'currentWirdIndex': currentWirdIndex,
      'notificationType': notificationType,
      'startDate': startDate.toIso8601String(),
      'days': days,
      'pagesPerWird': pagesPerWird,
    };
  }

  factory KhatmaModel.fromJson(Map<String, dynamic> json) {
    return KhatmaModel(
      wirds: (json['wirds'] as List).map((e) => WirdModel.fromJson(e)).toList(),
      currentWirdIndex: json['currentWirdIndex'] ?? 0,
      notificationType: json['notificationType'],
      startDate: DateTime.parse(json['startDate']),
      days: json['days'] ?? 30,
      pagesPerWird: json['pagesPerWird'] ?? 20,
    );
  }
}
