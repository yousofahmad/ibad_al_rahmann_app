class ShareCardCategory {
  final String categoryName;
  final List<ShareCardItem> items;

  ShareCardCategory({required this.categoryName, required this.items});

  factory ShareCardCategory.fromJson(Map<String, dynamic> json) {
    return ShareCardCategory(
      categoryName: json['category'] ?? '',
      items: (json['items'] as List?)
              ?.map((i) => ShareCardItem.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class ShareCardItem {
  final String title;
  final String url; // Relative path or absolute URL

  ShareCardItem({required this.title, required this.url});

  factory ShareCardItem.fromJson(Map<String, dynamic> json) {
    return ShareCardItem(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
