class AppSettings {
  const AppSettings({
    required this.autoRestoreWallpaperOnLaunch,
    required this.lastSelectedWallpaperId,
    required this.lastCustomWallpaperPath,
  });

  const AppSettings.defaults()
    : autoRestoreWallpaperOnLaunch = false,
      lastSelectedWallpaperId = null,
      lastCustomWallpaperPath = null;

  final bool autoRestoreWallpaperOnLaunch;
  final String? lastSelectedWallpaperId;
  final String? lastCustomWallpaperPath;

  AppSettings copyWith({
    bool? autoRestoreWallpaperOnLaunch,
    String? lastSelectedWallpaperId,
    String? lastCustomWallpaperPath,
    bool clearLastSelectedWallpaperId = false,
    bool clearLastCustomWallpaperPath = false,
  }) {
    return AppSettings(
      autoRestoreWallpaperOnLaunch:
          autoRestoreWallpaperOnLaunch ?? this.autoRestoreWallpaperOnLaunch,
      lastSelectedWallpaperId: clearLastSelectedWallpaperId
          ? null
          : (lastSelectedWallpaperId ?? this.lastSelectedWallpaperId),
      lastCustomWallpaperPath: clearLastCustomWallpaperPath
          ? null
          : (lastCustomWallpaperPath ?? this.lastCustomWallpaperPath),
    );
  }
}
