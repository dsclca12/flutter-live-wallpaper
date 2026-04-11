# HTML Wallpaper

A cross-platform Flutter app that uses HTML/CSS/JavaScript animations as live wallpapers. Supports **Windows** (desktop wallpaper) and **Android** (live wallpaper service).

## Features

- 🎨 **Built-in wallpapers** — 3 beautiful animated HTML wallpapers:
  - **Warm Fluid** — Soft gradient fluid animation
  - **Fluid Time** — Dark informational panel style
  - **Sunrise Glow** — Dynamic sky that changes with sunrise/sunset, with performance tuning
- 📂 **Custom wallpaper** — Import any HTML file
- ⚡ **Performance modes** — Quality / Balanced / Power / Minimal presets
- 🖥️ **Windows** — Attaches to desktop layer, supports auto-restore on launch and startup
- 📱 **Android** — Uses system live wallpaper service, no root required
- 🎛️ **Live tuning** — Adjust flow speed, wave amplitude, particle count, FPS, and resolution in real-time

## Screenshots

> TODO: Add screenshots for Windows and Android

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- **Windows**: WebView2 Runtime (usually pre-installed on Windows 10/11)
- **Android**: Android SDK, API 21+

### Build

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/html_wallpaper.git
cd wallpaper

# Install dependencies
flutter pub get

# Build for Windows
flutter build windows --release

# Build for Android
flutter build apk --release
```

### Windows Usage

1. Run the built exe from `build/windows/x64/runner/Release/`
2. Select a wallpaper and click "设为 Windows 壁纸"
3. The wallpaper will attach behind desktop icons
4. Right-click the system tray icon to restore settings or detach

### Android Usage

1. Install the APK on your device
2. Open the app and select a wallpaper
3. Click "设为安卓动态壁纸"
4. The system wallpaper picker will open — select HTML Wallpaper and apply
5. Xiaomi/MIUI devices: manually select HTML Wallpaper from the list

## Performance Modes

| Mode | FPS | Resolution | Effects | Use Case |
|------|-----|------------|---------|----------|
| 🎨 Quality | 60 | 100% | Full | Desktop PC |
| ⚖️ Balanced | 30 | 100% | Full | Daily use |
| 🔋 Power | 15 | 50% | No particles | Phone wallpaper |
| 🪶 Minimal | 5 | 25% | Color only | Ultra low power |

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── src/
│   ├── app.dart                        # Main UI
│   ├── models/
│   │   ├── app_settings.dart           # Settings model
│   │   └── wallpaper_source.dart       # Wallpaper source model
│   ├── preview/
│   │   ├── sunrise_settings.dart       # Sunrise wallpaper settings panel
│   │   ├── wallpaper_control_panel.dart # Generic control panel
│   │   └── wallpaper_preview.dart      # WebView preview widget
│   └── services/
│       ├── android_wallpaper_bridge.dart # Android native bridge
│       ├── app_settings_store.dart     # SharedPreferences persistence
│       ├── desktop_wallpaper_bridge.dart # Windows native bridge
│       └── wallpaper_catalog.dart      # Wallpaper catalog loader
wallpaper.html                          # Built-in: Warm Fluid
wallpaper2.html                         # Built-in: Fluid Time
wallpaper3.html                         # Built-in: Sunrise Glow
```

## API for Wallpaper HTML Files

HTML wallpapers can receive configuration via `window.setWallpaperConfig()`:

```javascript
// Receive config from Flutter
window.setWallpaperConfig = (cfg) => {
  if (typeof cfg.flowSpeed === 'number') config.flowSpeed = cfg.flowSpeed;
  if (typeof cfg.waveAmp === 'number') config.waveAmp = cfg.waveAmp;
  if (typeof cfg.targetFps === 'number') config.targetFps = cfg.targetFps;
  if (typeof cfg.simTime === 'number') config.simTime = cfg.simTime;
  // ... more params
};
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
