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
│       └── wallpaper_catalog.dart      # 壁纸目录加载器
wallpaper.html                          # 内置: Warm Fluid
wallpaper2.html                         # 内置: Fluid Time
wallpaper3.html                         # 内置: 晨曦流光
```

## HTML 壁纸 API

HTML 壁纸可通过 `window.setWallpaperConfig()` 接收 Flutter 端下发的配置：

```javascript
// 接收 Flutter 配置
window.setWallpaperConfig = (cfg) => {
  if (typeof cfg.flowSpeed === 'number') config.flowSpeed = cfg.flowSpeed;
  if (typeof cfg.waveAmp === 'number') config.waveAmp = cfg.waveAmp;
  if (typeof cfg.targetFps === 'number') config.targetFps = cfg.targetFps;
  if (typeof cfg.simTime === 'number') config.simTime = cfg.simTime;
  // ... 更多参数
};
```

## 参与贡献

欢迎贡献代码或提交 Issue！请打开 Issue 讨论或直接提交 Pull Request。

## 许可证

本项目采用 [MIT 许可证](LICENSE)。
