# HTML Wallpaper

A cross-platform Flutter app that uses HTML/CSS/JavaScript animations as live wallpapers. Supports **Windows** (desktop wallpaper) and **Android** (live wallpaper service).

[🇨🇳 中文版](README_ZH.md)

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
- 📊 **System info** — Wallpapers can access device battery, CPU, memory, and network data

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
│       ├── system_info_service.dart    # System info service
│       └── wallpaper_catalog.dart      # Wallpaper catalog loader
wallpaper.html                          # Built-in: Warm Fluid
wallpaper2.html                         # Built-in: Fluid Time
wallpaper3.html                         # Built-in: Sunrise Glow
```

## API for Wallpaper HTML Files

All HTML wallpapers can receive system data via `window.setWallpaperConfig()`. This works on both **Windows** and **Android** platforms.

### Basic Usage

Implement this function in your HTML:

```javascript
window.setWallpaperConfig = (cfg) => {
    // cfg object contains all available data, undefined if not available
    console.log('Received config:', cfg);
    
    // Use data to update UI
    if (cfg.batteryLevel !== undefined) {
        document.getElementById('battery').textContent = Math.round(cfg.batteryLevel) + '%';
    }
};
```

### System Info Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `batteryLevel` | `number?` | Battery level (0-100) | `85.5` |
| `isCharging` | `boolean?` | Is charging | `true` |
| `batteryState` | `string?` | Battery state | `'charging'`, `'discharging'`, `'full'` |
| `cpuUsage` | `number?` | CPU usage (0-100) | `45.2` |
| `totalMemory` | `number?` | Total memory (MB) | `16384.0` |
| `usedMemory` | `number?` | Used memory (MB) | `8192.0` |
| `memoryUsagePercent` | `number?` | Memory usage % (0-100) | `50.0` |
| `wifiName` | `string?` | WiFi name | `'MyWiFi'` |
| `wifiIP` | `string?` | WiFi IP address | `'192.168.1.100'` |
| `networkType` | `string?` | Network type | `'WiFi'`, `'Mobile'`, `'Ethernet'` |
| `timestamp` | `number` | Data timestamp (ms) | `1712908800000` |

### Wallpaper Control Parameters

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `flowSpeed` | `number` | Flow speed | `5.0` |
| `waveAmp` | `number` | Wave amplitude | `0.7` |
| `cssBlur` | `number` | Blur amount (px) | `0.0` |
| `useRealTime` | `boolean` | Use real-time clock | `true` |
| `simTime` | `number?` | Simulated time (hours) | `18.5` |
| `simMonth` | `number?` | Simulated month (0-11) | `5` |

### Update Frequency

- **Android wallpaper service**: Every 5 seconds
- **Windows wallpaper**: Every 5 seconds (in Flutter app)
- **Control parameters**: Immediately when user adjusts

### Notes

1. **All system info fields are optional** (except `timestamp`), `undefined` if fetch fails
2. **Function is called first time after wallpaper loads**, then updates periodically (default 5s interval)
3. **Android wallpaper service** is native Kotlin implementation, independent of Flutter
4. **Always check field existence** before use: `if (cfg.batteryLevel !== undefined)`
5. **Android 10+ requires location permission** for WiFi name, returns `null` if denied

### Minimal Example

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>System Info Wallpaper</title>
    <style>
        body { background: #1a1a2e; color: white; font-family: Arial; padding: 50px; }
        .info { font-size: 24px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="info">🔋 Battery: <span id="battery">--</span>%</div>
    <div class="info">💻 CPU: <span id="cpu">--</span>%</div>
    <div class="info">🧠 Memory: <span id="memory">--</span>%</div>

    <script>
        window.setWallpaperConfig = (cfg) => {
            if (cfg.batteryLevel !== undefined) 
                document.getElementById('battery').textContent = Math.round(cfg.batteryLevel);
            if (cfg.cpuUsage !== undefined) 
                document.getElementById('cpu').textContent = Math.round(cfg.cpuUsage);
            if (cfg.memoryUsagePercent !== undefined) 
                document.getElementById('memory').textContent = Math.round(cfg.memoryUsagePercent);
        };
    </script>
</body>
</html>
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
