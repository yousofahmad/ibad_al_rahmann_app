class CompletedKhatmaModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime completedDate;
  final int daysPlanned;
  final int actualDays;
  final int totalWirds;
  final int pagesCount;
  final String notificationType;

  CompletedKhatmaModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.completedDate,
    required this.daysPlanned,
    required this.actualDays,
    required this.totalWirds,
    this.pagesCount = 604,
    required this.notificationType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'completedDate': completedDate.toIso8601String(),
      'daysPlanned': daysPlanned,
      'actualDays': actualDays,
      'totalWirds': totalWirds,
      'pagesCount': pagesCount,
      'notificationType': notificationType,
    };
  }

  factory CompletedKhatmaModel.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now();
    final completed =
        DateTime.tryParse(json['completedDate'] ?? '') ?? DateTime.now();
    final diffDays = completed.difference(start).inDays;
    final fallbackActualDays = diffDays <= 0 ? 1 : diffDays + 1;

    return CompletedKhatmaModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'ختمة القرآن الكريم',
      startDate: start,
      completedDate: completed,
      daysPlanned: json['daysPlanned'] ?? 30,
      actualDays: json['actualDays'] ?? fallbackActualDays,
      totalWirds: json['totalWirds'] ?? 30,
      pagesCount: json['pagesCount'] ?? 604,
      notificationType: json['notificationType'] ?? 'daily',
    );
  }
}
