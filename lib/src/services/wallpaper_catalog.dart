import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/wallpaper_source.dart';

class WallpaperCatalog {
  const WallpaperCatalog();

  static const List<(String assetPath, String title, String subtitle)>
  _bundledWallpapers = [
    ('wallpaper.html', 'Warm Fluid', '柔和渐变和流体动画，适合做默认桌面背景。'),
    ('wallpaper2.html', 'Fluid Time', '更偏暗色和信息面板风格，适合做实验性动态壁纸。'),
    ('wallpaper3.html', '晨曦流光', '随日出日落变化的动态天空，支持性能调节。'),
    ('wallpaper_time.html', '时光流转', '根据时间自动变换色调， subtle 不干扰工作。'),
    ('wallpaper_window.html', '天际流光', '随一天24小时与天气变化的天空光景，宁静不打扰，支持静态Canvas模式。'),
  ];

  /// 支持的图片扩展名
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  
  /// 支持的动图扩展名
  static const List<String> gifExtensions = ['gif'];
  
  /// 支持的视频扩展名
  static const List<String> videoExtensions = ['mp4', 'webm'];
  
  /// 所有支持的媒体格式
  static List<String> get allSupportedExtensions => [
    'html', 'htm',
    ...imageExtensions,
    ...gifExtensions,
    ...videoExtensions,
  ];

  Future<List<WallpaperSource>> loadBundledWallpapers() async {
    final wallpapers = <WallpaperSource>[];
    for (final (assetPath, title, subtitle) in _bundledWallpapers) {
      final htmlContent = await rootBundle.loadString(assetPath);
      wallpapers.add(
        WallpaperSource(
          id: assetPath,
          title: title,
          subtitle: subtitle,
          htmlContent: htmlContent,
          originLabel: '内置资源',
          mediaType: WallpaperMediaType.html,
        ),
      );
    }
    return wallpapers;
  }

  /// 选择自定义壁纸文件（支持 HTML、图片、GIF、视频）
  Future<WallpaperSource?> pickCustomWallpaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allSupportedExtensions,
      dialogTitle: '选择壁纸文件（支持 HTML、图片、GIF、视频）',
    );
    final filePath = result?.files.singleOrNull?.path;
    if (filePath == null) {
      return null;
    }

    return loadWallpaperFromPath(filePath);
  }

  /// 从文件路径加载壁纸，自动识别类型
  Future<WallpaperSource?> loadWallpaperFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final fileName = path.basename(filePath);
    final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
    
    // 根据文件扩展名判断媒体类型
    WallpaperMediaType mediaType;
    String? htmlContent;
    String subtitle;
    
    if (imageExtensions.contains(extension)) {
      mediaType = WallpaperMediaType.image;
      subtitle = '图片文件';
    } else if (gifExtensions.contains(extension)) {
      mediaType = WallpaperMediaType.gif;
      subtitle = 'GIF 动图';
    } else if (videoExtensions.contains(extension)) {
      mediaType = WallpaperMediaType.video;
      subtitle = '视频文件';
    } else if (['html', 'htm'].contains(extension)) {
      mediaType = WallpaperMediaType.html;
      htmlContent = await file.readAsString();
      subtitle = 'HTML 网页壁纸';
    } else {
      // 默认当作图片处理
      mediaType = WallpaperMediaType.image;
      subtitle = '媒体文件';
    }

    return WallpaperSource(
      id: 'custom:$filePath',
      title: fileName,
      subtitle: subtitle,
      htmlContent: htmlContent,
      originLabel: filePath,
      filePath: filePath,
      mediaType: mediaType,
    );
  }
}
