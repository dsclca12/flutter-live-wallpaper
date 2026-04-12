# HTML Wallpaper

一个跨平台 Flutter 应用，使用 HTML/CSS/JavaScript 动画作为动态壁纸。支持 **Windows**（桌面壁纸）和 **Android**（动态壁纸服务）。

<a href="https://github.com/YOUR_USERNAME/html_wallpaper">English</a>

## 功能特性

- 🎨 **内置壁纸** — 3 款精美的 HTML 动画壁纸：
  - **Warm Fluid** — 柔和渐变的流体动画
  - **Fluid Time** — 暗色系信息面板风格
  - **晨曦流光** — 随日出日落变化的动态天空，支持性能调节
- 📂 **自定义壁纸** — 导入任意 HTML 文件
- ⚡ **性能模式** — 高质量 / 均衡 / 省电 / 极低 四档预设
- 🖥️ **Windows** — 挂到桌面图标后面，支持启动自动恢复和开机自启
- 📱 **Android** — 使用系统动态壁纸服务，无需 root
- 🎛️ **实时调节** — 在设置面板中实时调整流速、幅度、粒子数、帧率和分辨率
- 📊 **系统信息** — 壁纸可获取电池、CPU、内存、网络等本机数据

## 截图

> TODO: 添加 Windows 和 Android 截图

## 快速开始

### 环境要求

- Flutter SDK（stable 频道）
- **Windows**: WebView2 Runtime（Windows 10/11 通常已预装）
- **Android**: Android SDK，API 21+

### 构建

```bash
# 克隆项目
git clone https://github.com/YOUR_USERNAME/html_wallpaper.git
cd wallpaper

# 安装依赖
flutter pub get

# 构建 Windows
flutter build windows --release

# 构建 Android
flutter build apk --release
```

### Windows 使用方法

1. 运行 `build/windows/x64/runner/Release/` 下的 exe
2. 选择壁纸并点击"设为 Windows 壁纸"
3. 壁纸将附加到桌面图标后面
4. 右键系统托盘图标可恢复设置或解除

### Android 使用方法

1. 安装 APK 到手机
2. 打开应用并选择壁纸
3. 点击"设为安卓动态壁纸"
4. 系统将打开壁纸选择器 — 选择 HTML Wallpaper 并应用
5. 小米/MIUI 设备：在列表中手动选择 HTML Wallpaper

## 性能模式

| 模式 | 帧率 | 分辨率 | 特效 | 适用场景 |
|------|------|--------|------|----------|
| 🎨 高质量 | 60fps | 100% | 完整 | 台式电脑 |
| ⚖️ 均衡 | 30fps | 100% | 完整 | 日常使用 |
| 🔋 省电 | 15fps | 50% | 无粒子 | 手机壁纸 |
| 🪶 极低 | 5fps | 25% | 仅变色 | 超低功耗 |

## 项目结构

```
lib/
├── main.dart                           # 应用入口
├── src/
│   ├── app.dart                        # 主界面 UI
│   ├── models/
│   │   ├── app_settings.dart           # 设置数据模型
│   │   └── wallpaper_source.dart       # 壁纸来源模型
│   ├── preview/
│   │   ├── sunrise_settings.dart       # 晨曦流光专属设置面板
│   │   ├── wallpaper_control_panel.dart # 通用控制面板
│   │   └── wallpaper_preview.dart      # WebView 预览组件
│   └── services/
│       ├── android_wallpaper_bridge.dart # Android 原生桥接
│       ├── app_settings_store.dart     # SharedPreferences 持久化
│       ├── desktop_wallpaper_bridge.dart # Windows 原生桥接
│       ├── system_info_service.dart    # 系统信息服务
│       └── wallpaper_catalog.dart      # 壁纸目录加载器
wallpaper.html                          # 内置: Warm Fluid
wallpaper2.html                         # 内置: Fluid Time
wallpaper3.html                         # 内置: 晨曦流光
```

## 📡 HTML 壁纸 API 完整文档

所有 HTML 壁纸都可以通过 `window.setWallpaperConfig()` 接收来自应用的数据。该接口在 **Windows** 和 **Android** 平台均有效。

### 📥 基本用法

在你的 HTML 文件中实现该函数：

```javascript
window.setWallpaperConfig = (cfg) => {
    // cfg 对象包含所有可用数据，未获取到的字段为 undefined
    console.log('收到配置:', cfg);
    
    // 使用数据更新 UI
    if (cfg.batteryLevel !== undefined) {
        document.getElementById('battery').textContent = Math.round(cfg.batteryLevel) + '%';
    }
};
```

### 📊 系统信息字段

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `batteryLevel` | `number?` | 电池电量 (0-100) | `85.5` |
| `isCharging` | `boolean?` | 是否充电中 | `true` |
| `batteryState` | `string?` | 充电状态 | `'charging'`, `'discharging'`, `'full'` |
| `cpuUsage` | `number?` | CPU 使用率 (0-100) | `45.2` |
| `totalMemory` | `number?` | 总内存 (MB) | `16384.0` |
| `usedMemory` | `number?` | 已用内存 (MB) | `8192.0` |
| `memoryUsagePercent` | `number?` | 内存使用率 (0-100) | `50.0` |
| `wifiName` | `string?` | WiFi 名称 | `'MyWiFi'` |
| `wifiIP` | `string?` | WiFi IP 地址 | `'192.168.1.100'` |
| `networkType` | `string?` | 网络类型 | `'WiFi'`, `'Mobile'`, `'Ethernet'` |
| `timestamp` | `number` | 数据时间戳 (毫秒) | `1712908800000` |

### 🎛️ 壁纸控制参数

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `flowSpeed` | `number` | 流动速度 | `5.0` |
| `waveAmp` | `number` | 波浪幅度 | `0.7` |
| `cssBlur` | `number` | 模糊度 (px) | `0.0` |
| `useRealTime` | `boolean` | 使用实时时间 | `true` |
| `simTime` | `number?` | 模拟时间 (小时) | `18.5` |
| `simMonth` | `number?` | 模拟月份 (0-11) | `5` |

### ⚙️ 更新频率

- **Android 壁纸服务**: 每 5 秒更新一次
- **Windows 壁纸**: 每 5 秒更新一次（在 Flutter 应用中）
- **控制参数**: 用户调整时立即推送

### 📝 完整示例

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>系统监控壁纸</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Microsoft YaHei', Arial, sans-serif;
            overflow: hidden;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            position: absolute;
            top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 30px;
            max-width: 800px;
            padding: 40px;
        }
        .info-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .info-icon { font-size: 48px; margin-bottom: 15px; }
        .info-label { font-size: 14px; opacity: 0.8; margin-bottom: 10px; }
        .info-value { font-size: 36px; font-weight: bold; margin-bottom: 5px; }
        .info-sub { font-size: 12px; opacity: 0.7; }
        .progress-bar {
            width: 100%; height: 8px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 10px; overflow: hidden;
            margin-top: 15px;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #00d4ff, #00ff88);
            border-radius: 10px;
            transition: width 0.5s ease;
        }
        .title {
            font-size: 48px; font-weight: bold;
            margin-bottom: 40px;
            text-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .charging { animation: pulse 2s infinite; color: #00ff88; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="title">📊 系统监控面板</h1>
        
        <div class="info-grid">
            <!-- 电池信息 -->
            <div class="info-card">
                <div class="info-icon">🔋</div>
                <div class="info-label">电池电量</div>
                <div class="info-value" id="battery-level">--%</div>
                <div class="info-sub" id="battery-state">等待数据...</div>
                <div class="progress-bar">
                    <div class="progress-fill" id="battery-bar" style="width: 0%"></div>
                </div>
            </div>

            <!-- CPU 使用率 -->
            <div class="info-card">
                <div class="info-icon">💻</div>
                <div class="info-label">CPU 使用率</div>
                <div class="info-value" id="cpu-usage">--%</div>
                <div class="info-sub">处理器负载</div>
                <div class="progress-bar">
                    <div class="progress-fill" id="cpu-bar" style="width: 0%"></div>
                </div>
            </div>

            <!-- 内存使用 -->
            <div class="info-card">
                <div class="info-icon">🧠</div>
                <div class="info-label">内存使用</div>
                <div class="info-value" id="memory-usage">--%</div>
                <div class="info-sub" id="memory-detail">-- / -- GB</div>
                <div class="progress-bar">
                    <div class="progress-fill" id="memory-bar" style="width: 0%"></div>
                </div>
            </div>

            <!-- 网络信息 -->
            <div class="info-card">
                <div class="info-icon">🌐</div>
                <div class="info-label">网络状态</div>
                <div class="info-value" id="network-type">--</div>
                <div class="info-sub" id="network-name">等待数据...</div>
            </div>
        </div>
    </div>

    <script>
        window.setWallpaperConfig = (cfg) => {
            // 更新电池信息
            if (cfg.batteryLevel !== undefined) {
                document.getElementById('battery-level').textContent = Math.round(cfg.batteryLevel) + '%';
                document.getElementById('battery-bar').style.width = cfg.batteryLevel + '%';
                
                const bar = document.getElementById('battery-bar');
                if (cfg.batteryLevel < 20) {
                    bar.style.background = 'linear-gradient(90deg, #ff4444, #ff6b6b)';
                } else if (cfg.batteryLevel < 50) {
                    bar.style.background = 'linear-gradient(90deg, #ffaa00, #ffcc00)';
                } else {
                    bar.style.background = 'linear-gradient(90deg, #00d4ff, #00ff88)';
                }
            }
            
            if (cfg.isCharging !== undefined) {
                const stateEl = document.getElementById('battery-state');
                if (cfg.isCharging) {
                    stateEl.innerHTML = '<span class="charging">⚡ 充电中</span>';
                } else if (cfg.batteryState === 'full') {
                    stateEl.textContent = '✓ 已充满';
                } else {
                    stateEl.textContent = '🔌 未充电';
                }
            }
            
            // 更新 CPU 信息
            if (cfg.cpuUsage !== undefined) {
                document.getElementById('cpu-usage').textContent = Math.round(cfg.cpuUsage) + '%';
                document.getElementById('cpu-bar').style.width = cfg.cpuUsage + '%';
                
                const bar = document.getElementById('cpu-bar');
                if (cfg.cpuUsage > 80) {
                    bar.style.background = 'linear-gradient(90deg, #ff4444, #ff6b6b)';
                } else if (cfg.cpuUsage > 50) {
                    bar.style.background = 'linear-gradient(90deg, #ffaa00, #ffcc00)';
                } else {
                    bar.style.background = 'linear-gradient(90deg, #00d4ff, #00ff88)';
                }
            }
            
            // 更新内存信息
            if (cfg.memoryUsagePercent !== undefined) {
                document.getElementById('memory-usage').textContent = Math.round(cfg.memoryUsagePercent) + '%';
                document.getElementById('memory-bar').style.width = cfg.memoryUsagePercent + '%';
            }
            
            if (cfg.totalMemory !== undefined && cfg.usedMemory !== undefined) {
                const usedGB = (cfg.usedMemory / 1024).toFixed(1);
                const totalGB = (cfg.totalMemory / 1024).toFixed(1);
                document.getElementById('memory-detail').textContent = `${usedGB} / ${totalGB} GB`;
            }
            
            // 更新网络信息
            if (cfg.networkType !== undefined) {
                document.getElementById('network-type').textContent = cfg.networkType;
            }
        };
    </script>
</body>
</html>
```

### 📌 注意事项

1. **所有系统信息字段都是可选的**（除 `timestamp` 外），如果获取失败则为 `undefined`
2. **函数会在壁纸加载完成后首次调用**，之后定期更新（默认 5 秒间隔）
3. **Android 壁纸服务**是原生 Kotlin 实现，不依赖 Flutter 代码
4. **建议在使用前检查字段是否存在**：`if (cfg.batteryLevel !== undefined)`
5. **Android 10+ 获取 WiFi 名称需要位置权限**，如果用户拒绝则返回 `null`

### 🔧 最小示例

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

## 参与贡献

欢迎贡献代码或提交 Issue！请打开 Issue 讨论或直接提交 Pull Request。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。
