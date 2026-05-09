import 'dart:convert';

import 'package:flutter/material.dart';

/// 壁纸参数配置模型
class WallpaperConfig {
  final double flowSpeed;
  final double waveAmp;
  final double cssBlur;
  final bool useRealTime;
  final double? simTime;
  final int? simMonth;
  
  // 系统信息字段
  final double? batteryLevel;        // 电池电量 0-100
  final bool? isCharging;            // 是否充电中
  final String? batteryState;        // 充电状态
  final double? cpuUsage;            // CPU 使用率
  final double? totalMemory;         // 总内存 (MB)
  final double? usedMemory;          // 已用内存 (MB)
  final double? memoryUsagePercent;  // 内存使用率
  final String? wifiName;            // WiFi 名称
  final String? wifiIP;              // WiFi IP
  final String? networkType;         // 网络类型
  final String? timestamp;           // 时间戳

  // 天气模拟字段
  final String? weatherCondition;    // 天气条件: sunny/cloudy/rain/snow/fog
  final double? temperature;         // 温度 (°C)
  final double? humidity;            // 湿度 0-100

  // 静态Canvas模式（大幅降低GPU开销）
  final bool staticMode;

  const WallpaperConfig({
    this.flowSpeed = 5.0,
    this.waveAmp = 0.7,
    this.cssBlur = 0.0,
    this.useRealTime = true,
    this.simTime,
    this.simMonth,
    this.batteryLevel,
    this.isCharging,
    this.batteryState,
    this.cpuUsage,
    this.totalMemory,
    this.usedMemory,
    this.memoryUsagePercent,
    this.wifiName,
    this.wifiIP,
    this.networkType,
    this.timestamp,
    this.weatherCondition,
    this.temperature,
    this.humidity,
    this.staticMode = false,
  });

  WallpaperConfig copyWith({
    double? flowSpeed,
    double? waveAmp,
    double? cssBlur,
    bool? useRealTime,
    double? simTime,
    int? simMonth,
    double? batteryLevel,
    bool? isCharging,
    String? batteryState,
    double? cpuUsage,
    double? totalMemory,
    double? usedMemory,
    double? memoryUsagePercent,
    String? wifiName,
    String? wifiIP,
    String? networkType,
    String? timestamp,
    String? weatherCondition,
    double? temperature,
    double? humidity,
    bool? staticMode,
  }) {
    return WallpaperConfig(
      flowSpeed: flowSpeed ?? this.flowSpeed,
      waveAmp: waveAmp ?? this.waveAmp,
      cssBlur: cssBlur ?? this.cssBlur,
      useRealTime: useRealTime ?? this.useRealTime,
      simTime: simTime ?? this.simTime,
      simMonth: simMonth ?? this.simMonth,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      batteryState: batteryState ?? this.batteryState,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      totalMemory: totalMemory ?? this.totalMemory,
      usedMemory: usedMemory ?? this.usedMemory,
      memoryUsagePercent: memoryUsagePercent ?? this.memoryUsagePercent,
      wifiName: wifiName ?? this.wifiName,
      wifiIP: wifiIP ?? this.wifiIP,
      networkType: networkType ?? this.networkType,
      timestamp: timestamp ?? this.timestamp,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      staticMode: staticMode ?? this.staticMode,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'flowSpeed': flowSpeed,
      'waveAmp': waveAmp,
      'cssBlur': cssBlur,
      'useRealTime': useRealTime,
    };
    if (simTime != null) map['simTime'] = simTime;
    if (simMonth != null) map['simMonth'] = simMonth;
    
    // 系统信息
    if (batteryLevel != null) map['batteryLevel'] = batteryLevel;
    if (isCharging != null) map['isCharging'] = isCharging;
    if (batteryState != null) map['batteryState'] = batteryState;
    if (cpuUsage != null) map['cpuUsage'] = cpuUsage;
    if (totalMemory != null) map['totalMemory'] = totalMemory;
    if (usedMemory != null) map['usedMemory'] = usedMemory;
    if (memoryUsagePercent != null) map['memoryUsagePercent'] = memoryUsagePercent;
    if (wifiName != null) map['wifiName'] = wifiName;
    if (wifiIP != null) map['wifiIP'] = wifiIP;
    if (networkType != null) map['networkType'] = networkType;
    if (timestamp != null) map['timestamp'] = timestamp;

    // 天气模拟
    if (weatherCondition != null) map['weatherCondition'] = weatherCondition;
    if (temperature != null) map['temperature'] = temperature;
    if (humidity != null) map['humidity'] = humidity;

    // 静态模式
    map['staticMode'] = staticMode;

    return map;
  }

  String toPostMessageJson() {
    return jsonEncode(toJson());
  }
}

/// 壁纸控制面板组件
class WallpaperControlPanel extends StatelessWidget {
  const WallpaperControlPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.onSendMessage,
  });

  final WallpaperConfig config;
  final ValueChanged<WallpaperConfig> onConfigChanged;

  /// 可选：直接发送自定义消息到 WebView
  final void Function(String json)? onSendMessage;

  void _updateFlowSpeed(double value) {
    onConfigChanged(config.copyWith(flowSpeed: value));
    _sendMessage(config.copyWith(flowSpeed: value));
  }

  void _updateWaveAmp(double value) {
    onConfigChanged(config.copyWith(waveAmp: value));
    _sendMessage(config.copyWith(waveAmp: value));
  }

  void _updateCssBlur(double value) {
    onConfigChanged(config.copyWith(cssBlur: value));
    _sendMessage(config.copyWith(cssBlur: value));
  }

  void _updateUseRealTime(bool value) {
    onConfigChanged(config.copyWith(useRealTime: value));
    _sendMessage(config.copyWith(useRealTime: value));
  }

  void _updateSimTime(double value) {
    onConfigChanged(
      config.copyWith(simTime: value, useRealTime: false),
    );
    _sendMessage(config.copyWith(simTime: value, useRealTime: false));
  }

  void _updateSimMonth(int value) {
    onConfigChanged(
      config.copyWith(simMonth: value, useRealTime: false),
    );
    _sendMessage(config.copyWith(simMonth: value, useRealTime: false));
  }

  void _sendMessage(WallpaperConfig cfg) {
    if (onSendMessage != null) {
      onSendMessage!(cfg.toPostMessageJson());
    }
  }

  void _updateWeatherCondition(String value) {
    onConfigChanged(config.copyWith(weatherCondition: value));
    _sendMessage(config.copyWith(weatherCondition: value));
  }

  void _updateTemperature(double value) {
    onConfigChanged(config.copyWith(temperature: value));
    _sendMessage(config.copyWith(temperature: value));
  }

  void _updateHumidity(double value) {
    onConfigChanged(config.copyWith(humidity: value));
    _sendMessage(config.copyWith(humidity: value));
  }

  void _updateStaticMode(bool value) {
    onConfigChanged(config.copyWith(staticMode: value));
    _sendMessage(config.copyWith(staticMode: value));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF293649)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: const Color(0xFFE7B86B)),
              const SizedBox(width: 8),
              Text(
                '壁纸参数调节',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 静态Canvas模式开关
          SwitchListTile.adaptive(
            value: config.staticMode,
            contentPadding: EdgeInsets.zero,
            title: const Text('静态Canvas模式'),
            subtitle: Text(
              config.staticMode
                  ? '已启用：DOM预渲染为单帧Canvas，GPU开销极低'
                  : '已关闭：实时CSS渲染，参数调整更直观',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A1B6),
              ),
            ),
            onChanged: _updateStaticMode,
          ),
          const Divider(color: Color(0xFF293649), height: 1),
          const SizedBox(height: 12),

          // 流动速度
          _SliderRow(
            label: '流动速度',
            value: config.flowSpeed,
            min: 0.1,
            max: 5.0,
            divisions: 49,
            valueDisplay: config.flowSpeed.toStringAsFixed(1),
            onChanged: _updateFlowSpeed,
          ),
          const SizedBox(height: 10),

          // 波浪幅度
          _SliderRow(
            label: '波浪幅度',
            value: config.waveAmp,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            valueDisplay: config.waveAmp.toStringAsFixed(2),
            onChanged: _updateWaveAmp,
          ),
          const SizedBox(height: 10),

          // 模糊
          _SliderRow(
            label: '模糊度',
            value: config.cssBlur,
            min: 0.0,
            max: 50.0,
            divisions: 500,
            valueDisplay: '${config.cssBlur.toStringAsFixed(1)}px',
            onChanged: _updateCssBlur,
          ),
          const SizedBox(height: 12),

          // 使用实时时间开关
          SwitchListTile.adaptive(
            value: config.useRealTime,
            contentPadding: EdgeInsets.zero,
            title: const Text('使用实时时间'),
            subtitle: Text(
              config.useRealTime
                  ? '当前使用系统时间'
                  : '当前使用模拟时间: ${config.simTime?.toStringAsFixed(1) ?? '18.5'}h, ${config.simMonth != null ? '${config.simMonth! + 1}月' : '6月'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A1B6),
              ),
            ),
            onChanged: _updateUseRealTime,
          ),

          // 模拟时间（仅在不使用实时时间时显示）
          if (!config.useRealTime) ...[
            const SizedBox(height: 8),
            _SliderRow(
              label: '模拟时间',
              value: config.simTime ?? 18.5,
              min: 0.0,
              max: 24.0,
              divisions: 480,
              valueDisplay:
                  '${(config.simTime ?? 18.5).toStringAsFixed(1)}h',
              onChanged: _updateSimTime,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '模拟月份',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFAEB7C5),
                  ),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: config.simMonth ?? 5,
                  dropdownColor: const Color(0xFF182230),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                  items: List.generate(12, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text('${i + 1}月'),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) _updateSimMonth(v);
                  },
                ),
              ],
            ),
          ],

          // 天气模拟折叠区域
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF293649), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.cloud_rounded, color: const Color(0xFF94A1B6), size: 18),
              const SizedBox(width: 8),
              Text(
                '天气模拟',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAEB7C5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '天气条件',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAEB7C5),
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: config.weatherCondition ?? 'sunny',
                dropdownColor: const Color(0xFF182230),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'sunny', child: Text('☀️ 晴')),
                  DropdownMenuItem(value: 'cloudy', child: Text('☁️ 多云')),
                  DropdownMenuItem(value: 'rain', child: Text('🌧️ 雨')),
                  DropdownMenuItem(value: 'snow', child: Text('❄️ 雪')),
                  DropdownMenuItem(value: 'fog', child: Text('🌫️ 雾')),
                ],
                onChanged: (v) {
                  if (v != null) _updateWeatherCondition(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '温度',
            value: config.temperature ?? 20,
            min: -20.0,
            max: 45.0,
            divisions: 65,
            valueDisplay: '${(config.temperature ?? 20).toStringAsFixed(0)}°C',
            onChanged: _updateTemperature,
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '湿度',
            value: config.humidity ?? 50,
            min: 0.0,
            max: 100.0,
            divisions: 100,
            valueDisplay: '${(config.humidity ?? 50).toStringAsFixed(0)}%',
            onChanged: _updateHumidity,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueDisplay,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueDisplay;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFAEB7C5),
              ),
            ),
            Text(
              valueDisplay,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFE7B86B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: const Color(0xFFE7B86B),
            inactiveTrackColor: const Color(0xFF293649),
            thumbColor: const Color(0xFFE7B86B),
            overlayColor: const Color(0x33E7B86B),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
