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
    ('wallpaper4.html', '系统监控', '实时显示电池、CPU、内存和网络状态。'),
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
        ),
      );
    }
    return wallpapers;
  }

  Future<WallpaperSource?> pickCustomWallpaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
      dialogTitle: '选择一个 HTML 文件',
    );
    final filePath = result?.files.singleOrNull?.path;
    if (filePath == null) {
      return null;
    }

    return loadWallpaperFromPath(filePath);
  }

  Future<WallpaperSource?> loadWallpaperFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final htmlContent = await File(filePath).readAsString();
    final fileName = path.basename(filePath);
    return WallpaperSource(
      id: 'custom:$filePath',
      title: fileName,
      subtitle: '外部 HTML 文件',
      htmlContent: htmlContent,
      originLabel: filePath,
      filePath: filePath,
    );
  }
}
