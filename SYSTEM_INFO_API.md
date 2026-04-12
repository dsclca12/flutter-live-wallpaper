# 系统信息 API

所有 HTML 壁纸都可以通过 `window.setWallpaperConfig()` 接收系统信息数据。

## 📡 数据格式

```javascript
window.setWallpaperConfig = (cfg) => {
    // cfg 对象包含以下字段（未获取到的字段为 undefined）
};
```

## 🔧 可用字段

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `batteryLevel` | `number?` | 电池电量 (0-100) | `85.5` |
| `isCharging` | `boolean?` | 是否充电中 | `true` |
| `batteryState` | `string?` | 充电状态 | `'charging'`, `'discharging'`, `'full'` |
| `cpuUsage` | `number?` | CPU 使用率 (0-100) | `45.2` |
| `totalMemory` | `number?` | 总内存 (MB) | `16384.0` |
| `usedMemory` | `number?` | 已用内存 (MB) | `8192.0` |
| `memoryUsagePercent` | `number?` | 内存使用率 (0-100) | `50.0` |
| `wifiName` | `string?` | 网络类型 | `'WiFi'`, `'Mobile'`, `'Ethernet'` |
| `wifiIP` | `string?` | WiFi IP 地址 | `'192.168.1.100'` |
| `networkType` | `string?` | 网络类型 | `'WiFi'`, `'Mobile'` |
| `timestamp` | `number` | 数据时间戳 (毫秒) | `1712908800000` |

## 📝 使用示例

### 最小示例

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

### 完整示例

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
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
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

## ⚙️ 更新频率

- **Android 壁纸服务**: 每 5 秒更新一次
- **Windows 壁纸**: 每 5 秒更新一次（在 Flutter 应用中）

## 📌 注意事项

1. 所有字段都是**可选的**（除 `timestamp` 外），如果获取失败则为 `undefined`
2. 函数会在壁纸加载完成后首次调用，之后定期更新
3. Android 壁纸服务原生实现，不依赖 Flutter
4. 建议在使用前检查字段是否存在：`if (cfg.batteryLevel !== undefined)`
