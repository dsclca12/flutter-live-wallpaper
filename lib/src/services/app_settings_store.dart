import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsStore {
  AppSettingsStore._(this._preferences);

  static const String _autoRestoreKey = 'settings.auto_restore_on_launch';
  static const String _lastWallpaperIdKey = 'settings.last_wallpaper_id';
  static const String _lastCustomPathKey =
      'settings.last_custom_wallpaper_path';

  final SharedPreferencesAsync _preferences;

  static Future<AppSettingsStore> create() async {
    return AppSettingsStore._(SharedPreferencesAsync());
  }

  Future<AppSettings> load() async {
    return AppSettings(
      autoRestoreWallpaperOnLaunch:
          await _preferences.getBool(_autoRestoreKey) ?? false,
      lastSelectedWallpaperId: await _preferences.getString(
        _lastWallpaperIdKey,
      ),
      lastCustomWallpaperPath: await _preferences.getString(_lastCustomPathKey),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _preferences.setBool(
      _autoRestoreKey,
      settings.autoRestoreWallpaperOnLaunch,
    );

    if (settings.lastSelectedWallpaperId case final String wallpaperId) {
      await _preferences.setString(_lastWallpaperIdKey, wallpaperId);
    } else {
      await _preferences.remove(_lastWallpaperIdKey);
    }

    if (settings.lastCustomWallpaperPath case final String customPath) {
      await _preferences.setString(_lastCustomPathKey, customPath);
    } else {
      await _preferences.remove(_lastCustomPathKey);
    }
  }
}
