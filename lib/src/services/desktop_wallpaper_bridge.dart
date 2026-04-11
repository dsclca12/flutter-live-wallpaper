import 'dart:io';

import 'package:flutter/services.dart';

class DesktopWallpaperBridge {
  DesktopWallpaperBridge._();

  static const MethodChannel _channel = MethodChannel('html_wallpaper/desktop');

  static bool get isSupported => Platform.isWindows;

  static Future<bool> attachToDesktop() async {
    if (!isSupported) {
      return false;
    }
    final bool? attached = await _channel.invokeMethod<bool>('attachToDesktop');
    return attached ?? false;
  }

  static Future<bool> detachFromDesktop() async {
    if (!isSupported) {
      return false;
    }
    final bool? detached = await _channel.invokeMethod<bool>(
      'detachFromDesktop',
    );
    return detached ?? false;
  }

  static Future<bool> isAttached() async {
    if (!isSupported) {
      return false;
    }
    final bool? attached = await _channel.invokeMethod<bool>('isAttached');
    return attached ?? false;
  }

  static Future<String?> getDesktopStatus() async {
    if (!isSupported) {
      return null;
    }
    return _channel.invokeMethod<String>('getDesktopStatus');
  }

  static Future<bool> getLaunchAtStartup() async {
    if (!isSupported) {
      return false;
    }
    final bool? enabled = await _channel.invokeMethod<bool>(
      'getLaunchAtStartup',
    );
    return enabled ?? false;
  }

  static Future<bool> setLaunchAtStartup(bool enabled) async {
    if (!isSupported) {
      return false;
    }
    final bool? result = await _channel.invokeMethod<bool>(
      'setLaunchAtStartup',
      enabled,
    );
    return result ?? false;
  }
}
