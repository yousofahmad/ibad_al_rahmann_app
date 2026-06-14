class Muezzin {
  final String id;
  final String name;
  final String country;
  final String category; // 'Egypt', 'Makkah', etc.
  final String url; // Remote URL
  bool isDownloaded;

  Muezzin({
    required this.id,
    required this.name,
    required this.country,
    required this.category,
    required this.url,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'category': category,
      'url': url,
      'isDownloaded': isDownloaded,
    };
  }

  factory Muezzin.fromJson(Map<String, dynamic> json) {
    return Muezzin(
      id: json['id'],
      name: json['name'],
      country: json['country'],
      category: json['category'],
      url: json['url'],
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }
}
