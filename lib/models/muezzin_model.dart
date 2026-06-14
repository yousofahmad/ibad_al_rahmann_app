class Muezzin {
  final String id;
  final String name;
  final String url;
  final String fileName;
  bool isDownloaded;
  String? localPath;

  Muezzin({
    required this.id,
    required this.name,
    required this.url,
    required this.fileName,
    this.isDownloaded = false,
    this.localPath,
  });
}
