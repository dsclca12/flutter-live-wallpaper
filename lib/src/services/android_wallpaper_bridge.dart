import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/wallpaper_source.dart';

class AndroidRenderConfig {
  const AndroidRenderConfig({
    required this.enabled,
    required this.scale,
  });

  final bool enabled;
  final double scale;

  static const AndroidRenderConfig defaults = AndroidRenderConfig(
    enabled: false,
    scale: 0.5,
  );
}

class AndroidWallpaperBridge {
  AndroidWallpaperBridge._();

  static const MethodChannel _channel = MethodChannel('html_wallpaper/android');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> prepareWallpaper(WallpaperSource wallpaper) async {
    if (!isSupported) {
      return false;
    }

    final bool? prepared = await _channel.invokeMethod<bool>(
      'prepareWallpaper',
      <String, Object?>{
        'html': wallpaper.htmlContent,
        'baseUrl': _baseUrlForWallpaper(wallpaper),
      },
    );
    return prepared ?? false;
  }

  static Future<bool> openWallpaperPicker() async {
    if (!isSupported) {
      return false;
    }

    final bool? opened = await _channel.invokeMethod<bool>(
      'openWallpaperPicker',
    );
    return opened ?? false;
  }

  static Future<bool> applyWallpaper(WallpaperSource wallpaper) async {
    final prepared = await prepareWallpaper(wallpaper);
    if (!prepared) {
      return false;
    }
    return openWallpaperPicker();
  }

  static Future<bool> isWallpaperActive() async {
    if (!isSupported) {
      return false;
    }

    final bool? active = await _channel.invokeMethod<bool>('isWallpaperActive');
    return active ?? false;
  }

  static Future<bool> getDynamicColorsEnabled() async {
    if (!isSupported) {
      return false;
    }

    final bool? enabled = await _channel.invokeMethod<bool>(
      'getDynamicColorsEnabled',
    );
    return enabled ?? false;
  }

  static Future<bool> setDynamicColorsEnabled(bool enabled) async {
    if (!isSupported) {
      return false;
    }

    final bool? updated = await _channel.invokeMethod<bool>(
      'setDynamicColorsEnabled',
      <String, Object?>{'enabled': enabled},
    );
    return updated ?? false;
  }

  static Future<bool> getAutoStartOnBootEnabled() async {
    if (!isSupported) {
      return false;
    }

    final bool? enabled = await _channel.invokeMethod<bool>(
      'getAutoStartOnBootEnabled',
    );
    return enabled ?? false;
  }

  static Future<bool> setAutoStartOnBootEnabled(bool enabled) async {
    if (!isSupported) {
      return false;
    }

    final bool? updated = await _channel.invokeMethod<bool>(
      'setAutoStartOnBootEnabled',
      <String, Object?>{'enabled': enabled},
    );
    return updated ?? false;
  }

  static Future<AndroidRenderConfig> getRenderConfig() async {
    if (!isSupported) {
      return AndroidRenderConfig.defaults;
    }

    final Map<Object?, Object?>? raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('getRenderConfig');
    if (raw == null) {
      return AndroidRenderConfig.defaults;
    }

    final enabled = raw['enabled'] == true;
    final scaleValue = raw['scale'];
    final scale = switch (scaleValue) {
      double value => value,
      int value => value.toDouble(),
      _ => AndroidRenderConfig.defaults.scale,
    };

    return AndroidRenderConfig(
      enabled: enabled,
      scale: scale.clamp(0.25, 1.0).toDouble(),
    );
  }

  static Future<bool> setRenderConfig({
    required bool enabled,
    required double scale,
  }) async {
    if (!isSupported) {
      return false;
    }

    final bool? updated = await _channel.invokeMethod<bool>(
      'setRenderConfig',
      <String, Object?>{
        'enabled': enabled,
        'scale': scale.clamp(0.25, 1.0).toDouble(),
      },
    );
    return updated ?? false;
  }

  static String? _baseUrlForWallpaper(WallpaperSource wallpaper) {
    final filePath = wallpaper.filePath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final directoryPath = path.dirname(filePath);
    final normalizedDirectory = directoryPath.endsWith(Platform.pathSeparator)
        ? directoryPath
        : '$directoryPath${Platform.pathSeparator}';
    return Uri.file(
      normalizedDirectory,
      windows: Platform.isWindows,
    ).toString();
  }
}
