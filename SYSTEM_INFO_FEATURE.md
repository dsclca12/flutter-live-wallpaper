# 系统信息传递功能说明

## 📋 功能概述

本项目现已支持从 Flutter 向 HTML 壁纸传递本机系统数据，包括：

- 🔋 **电池信息**：电量百分比、充电状态
- 💻 **CPU 使用率**：处理器负载
- 🧠 **内存使用**：总内存、已用内存、使用率
- 🌐 **网络状态**：WiFi 名称、IP 地址、网络类型

## 🏗️ 架构说明

### 1. 数据流

```
系统信息 (OS) 
  ↓
SystemInfoService (Flutter)
  ↓ (定时获取，默认 5 秒)
WallpaperConfig (JSON)
  ↓ (通过 JavaScript)
window.setWallpaperConfig() (HTML)
  ↓
更新 UI 显示
```

### 2. 核心文件

| 文件 | 说明 |
|------|------|
| `lib/src/services/system_info_service.dart` | 系统信息服务，负责获取本机数据 |
| `lib/src/preview/wallpaper_control_panel.dart` | 扩展了 WallpaperConfig 模型 |
| `lib/src/app.dart` | 集成定时推送系统信息到 HTML |
| `wallpaper4.html` | 示例壁纸，展示系统信息面板 |

## 🔧 使用方法

### 在 HTML 中接收系统信息

你的 HTML 壁纸需要实现 `window.setWallpaperConfig` 函数：

```javascript
window.setWallpaperConfig = (cfg) => {
    // 电池信息
    if (cfg.batteryLevel !== undefined) {
        console.log('电量:', cfg.batteryLevel + '%');
        console.log('充电中:', cfg.isCharging);
    }
    
    // CPU 使用率
    if (cfg.cpuUsage !== undefined) {
        console.log('CPU:', cfg.cpuUsage + '%');
    }
    
    // 内存使用
    if (cfg.memoryUsagePercent !== undefined) {
        console.log('内存使用率:', cfg.memoryUsagePercent + '%');
        console.log('已用:', cfg.usedMemory + ' MB');
        console.log('总计:', cfg.totalMemory + ' MB');
    }
    
    // 网络状态
    if (cfg.networkType !== undefined) {
        console.log('网络类型:', cfg.networkType);
    }
    if (cfg.wifiName !== undefined) {
        console.log('WiFi 名称:', cfg.wifiName);
    }
    if (cfg.wifiIP !== undefined) {
        console.log('IP 地址:', cfg.wifiIP);
    }
    
    // 更新时间戳
    if (cfg.timestamp !== undefined) {
        console.log('数据时间:', new Date(cfg.timestamp).toLocaleString());
    }
};
```

### 完整示例

参考 `wallpaper4.html`，它实现了一个漂亮的系统监控面板。

## ⚙️ 配置说明

### 更新频率

默认 **5 秒**更新一次系统信息。

如需修改，在 `lib/src/app.dart` 的 `_startSystemInfoUpdates()` 方法中调整：

```dart
void _startSystemInfoUpdates() {
  // 修改这里的间隔时间
  const interval = Duration(seconds: 5); // 改为 1 秒、10 秒等
  
  _systemInfoTimer = Timer.periodic(interval, (timer) async {
    // ...
  });
}
```

### 平台支持

| 系统信息 | Windows | Android | 说明 |
|---------|---------|---------|------|
| 电池电量 | ✅ | ✅ | 使用 battery_plus |
| CPU 使用率 | ✅ | ✅ | Windows 用 PowerShell，Android 读 /proc/stat |
| 内存使用 | ✅ | ✅ | Windows 用 WMI，Android 读 /proc/meminfo |
| WiFi 名称 | ✅ | ⚠️ | Android 10+ 需要位置权限 |
| WiFi IP | ✅ | ✅ | 使用 network_info_plus |
| 网络类型 | ⚠️ | ✅ | Android 可检测 WiFi/移动数据 |

#### Android 权限要求

已在 `AndroidManifest.xml` 中添加以下权限：

```xml
<!-- 系统信息获取权限 -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**注意**：
- Android 10+ (API 29+) 获取 WiFi 名称需要**位置权限**
- 应用会在运行时请求位置权限（首次使用时）
- 如果用户拒绝位置权限，`wifiName` 将返回 `null`，但其他功能正常

## 🎨 自定义 HTML 壁纸

### 方法 1：使用内置示例

直接使用 `wallpaper4.html`，它是一个完整的系统监控面板。

### 方法 2：创建自己的壁纸

1. 创建 HTML 文件
2. 实现 `window.setWallpaperConfig` 函数
3. 在 Flutter 项目中注册：
   - 添加到 `pubspec.yaml` 的 `assets` 部分
   - 在 `wallpaper_catalog.dart` 中注册到 `_bundledWallpapers` 列表

### 方法 3：导入外部 HTML

用户可以通过应用界面的"导入 HTML 文件"按钮选择自己的 HTML 壁纸。

## 📊 可用的数据字段

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `batteryLevel` | `number?` | 电池电量 0-100 | `85.5` |
| `isCharging` | `boolean?` | 是否充电中 | `true` |
| `batteryState` | `string?` | 充电状态 | `'charging'`, `'discharging'`, `'full'` |
| `cpuUsage` | `number?` | CPU 使用率 | `45.2` |
| `totalMemory` | `number?` | 总内存 (MB) | `16384.0` |
| `usedMemory` | `number?` | 已用内存 (MB) | `8192.0` |
| `memoryUsagePercent` | `number?` | 内存使用率 | `50.0` |
| `wifiName` | `string?` | WiFi 名称 | `'MyWiFi'` |
| `wifiIP` | `string?` | WiFi IP 地址 | `'192.168.1.100'` |
| `networkType` | `string?` | 网络类型 | `'WiFi'` |
| `timestamp` | `string` | 数据采集时间 (ISO 8601) | `'2024-01-01T12:00:00.000'` |

**注意**：所有系统信息字段都是可选的（`?`），如果获取失败会返回 `null`。

## 🚀 性能优化建议

1. **合理设置更新频率**：
   - 桌面壁纸：1-5 秒
   - 手机壁纸：10-30 秒
   - 省电模式：60 秒

2. **HTML 端优化**：
   - 使用 CSS 动画而非 JavaScript 动画显示数据
   - 避免频繁 DOM 操作
   - 使用 `requestAnimationFrame` 优化渲染

3. **Flutter 端优化**：
   - 系统信息获取失败时不影响其他功能
   - 使用异步操作避免阻塞 UI

## 🐛 故障排查

### 系统信息未显示

1. 检查 HTML 中是否正确实现了 `window.setWallpaperConfig`
2. 打开 WebView 开发者工具查看 JavaScript 错误
3. 确认平台支持所需的系统权限

### 某些字段为 null

- **CPU 使用率 (Android)**：当前简化实现返回 null，需要读取 `/proc/stat` 计算
- **网络信息**：需要位置权限（Android）或 WiFi 权限

### 性能问题

- 减少更新频率
- 简化 HTML 中的动画和特效
- 降低 WebView 分辨率

## 📝 示例代码

### 最简单的系统信息接收

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>System Info</title>
    <style>
        body { 
            background: #1a1a2e; 
            color: white; 
            font-family: Arial; 
            padding: 50px;
        }
        .info { font-size: 24px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="info">🔋 电量: <span id="battery">--</span>%</div>
    <div class="info">💻 CPU: <span id="cpu">--</span>%</div>
    <div class="info">🧠 内存: <span id="memory">--</span>%</div>
    
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

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个功能！

## 📄 许可证

MIT License
