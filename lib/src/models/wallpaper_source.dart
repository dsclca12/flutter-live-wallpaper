class WallpaperSource {
  const WallpaperSource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.htmlContent,
    required this.originLabel,
    this.filePath,
  });

  final String id;
  final String title;
  final String subtitle;
  final String htmlContent;
  final String originLabel;
  final String? filePath;

  bool get isCustomFile => filePath != null;
}
