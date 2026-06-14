class ZekrModel {
  final String content;
  final int count;

  ZekrModel({required this.content, required this.count});

  factory ZekrModel.fromJson(Map<String, dynamic> json) {
    return ZekrModel(
      content: json['zekr'] ?? '',
      count: int.tryParse(json['repeat'].toString()) ?? 1,
    );
  }
}
