/// 壁纸媒体类型枚举
enum WallpaperMediaType {
  html,      // HTML 网页壁纸
  image,     // 静态图片 (JPG, PNG, WebP)
  gif,       // GIF 动图
  video,     // 视频 (MP4, WebM)
}

class WallpaperSource {
  const WallpaperSource({
    required this.id,
    required this.title,
    required this.subtitle,
    this.htmlContent,
    this.filePath,
    required this.originLabel,
    this.mediaType = WallpaperMediaType.html,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? htmlContent;
  final String? filePath;
  final String originLabel;
  final WallpaperMediaType mediaType;

  bool get isCustomFile => filePath != null;
  
  /// 获取文件扩展名
  String? get fileExtension {
    if (filePath == null) return null;
    final parts = filePath!.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return null;
  }
  
  /// 判断是否为图片格式
  bool get isImage => mediaType == WallpaperMediaType.image;
  
  /// 判断是否为视频格式
  bool get isVideo => mediaType == WallpaperMediaType.video;
  
  /// 判断是否为动图
  bool get isGif => mediaType == WallpaperMediaType.gif;
  
  /// 判断是否为 HTML
  bool get isHtml => mediaType == WallpaperMediaType.html;
}
