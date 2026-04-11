import 'dart:convert';

import 'package:flutter/material.dart';

/// 晨曦流光壁纸专用配置
class SunriseConfig {
  final double flowSpeed;
  final double waveAmp;
  final int particleCount;
  final int targetFps;
  final double renderScale;
  final bool enableAnim;
  final bool enableParticles;
  final bool useRealTime;
  final double simTime;
  final int simMonth;

  const SunriseConfig({
    this.flowSpeed = 3.0,
    this.waveAmp = 0.6,
    this.particleCount = 80,
    this.targetFps = 60,
    this.renderScale = 1.0,
    this.enableAnim = true,
    this.enableParticles = true,
    this.useRealTime = true,
    this.simTime = 6.0,
    this.simMonth = 5,
  });

  SunriseConfig copyWith({
    double? flowSpeed,
    double? waveAmp,
    int? particleCount,
    int? targetFps,
    double? renderScale,
    bool? enableAnim,
    bool? enableParticles,
    bool? useRealTime,
    double? simTime,
    int? simMonth,
  }) {
    return SunriseConfig(
      flowSpeed: flowSpeed ?? this.flowSpeed,
      waveAmp: waveAmp ?? this.waveAmp,
      particleCount: particleCount ?? this.particleCount,
      targetFps: targetFps ?? this.targetFps,
      renderScale: renderScale ?? this.renderScale,
      enableAnim: enableAnim ?? this.enableAnim,
      enableParticles: enableParticles ?? this.enableParticles,
      useRealTime: useRealTime ?? this.useRealTime,
      simTime: simTime ?? this.simTime,
      simMonth: simMonth ?? this.simMonth,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flowSpeed': flowSpeed,
      'waveAmp': waveAmp,
      'particleCount': particleCount,
      'targetFps': targetFps,
      'renderScale': renderScale,
      'enableAnim': enableAnim,
      'enableParticles': enableParticles,
      'useRealTime': useRealTime,
      'simTime': simTime,
      'simMonth': simMonth,
    };
  }

  String toPostMessageJson() => jsonEncode(toJson());
}

/// 性能预设
enum PerformancePreset { quality, balanced, power, minimal }

extension PerformancePresetExt on PerformancePreset {
  String get label {
    switch (this) {
      case PerformancePreset.quality:
        return '🎨 高质量';
      case PerformancePreset.balanced:
        return '⚖️ 均衡';
      case PerformancePreset.power:
        return '🔋 省电';
      case PerformancePreset.minimal:
        return '🪶 极低';
    }
  }

  String get description {
    switch (this) {
      case PerformancePreset.quality:
        return '60fps · 全分辨率 · 完整特效';
      case PerformancePreset.balanced:
        return '30fps · 全分辨率 · 流畅体验';
      case PerformancePreset.power:
        return '15fps · 半分辨率 · 关闭粒子';
      case PerformancePreset.minimal:
        return '5fps · 1/4分辨率 · 仅时间变化';
    }
  }

  SunriseConfig apply(SunriseConfig config) {
    switch (this) {
      case PerformancePreset.quality:
        return config.copyWith(
          targetFps: 60,
          renderScale: 1.0,
          enableAnim: true,
          enableParticles: true,
        );
      case PerformancePreset.balanced:
        return config.copyWith(
          targetFps: 30,
          renderScale: 1.0,
          enableAnim: true,
          enableParticles: true,
        );
      case PerformancePreset.power:
        return config.copyWith(
          targetFps: 15,
          renderScale: 0.5,
          enableAnim: true,
          enableParticles: false,
        );
      case PerformancePreset.minimal:
        return config.copyWith(
          targetFps: 5,
          renderScale: 0.25,
          enableAnim: false,
          enableParticles: false,
        );
    }
  }
}

/// 晨曦流光壁纸设置面板
class SunriseWallpaperSettings extends StatefulWidget {
  const SunriseWallpaperSettings({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  final SunriseConfig config;
  final ValueChanged<SunriseConfig> onConfigChanged;

  @override
  State<SunriseWallpaperSettings> createState() =>
      _SunriseWallpaperSettingsState();
}

class _SunriseWallpaperSettingsState extends State<SunriseWallpaperSettings> {
  late SunriseConfig _config;
  PerformancePreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _selectedPreset = _detectPreset(_config);
  }

  @override
  void didUpdateWidget(covariant SunriseWallpaperSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameConfig(widget.config, oldWidget.config)) {
      _config = widget.config;
      _selectedPreset = _detectPreset(_config);
    }
  }

  PerformancePreset? _detectPreset(SunriseConfig config) {
    for (final preset in PerformancePreset.values) {
      final testConfig = const SunriseConfig();
      final applied = preset.apply(testConfig);
      if (config.targetFps == applied.targetFps &&
          config.renderScale == applied.renderScale &&
          config.enableAnim == applied.enableAnim &&
          config.enableParticles == applied.enableParticles) {
        return preset;
      }
    }
    return null;
  }

  bool _isSameConfig(SunriseConfig a, SunriseConfig b) {
    return a.flowSpeed == b.flowSpeed &&
        a.waveAmp == b.waveAmp &&
        a.particleCount == b.particleCount &&
        a.targetFps == b.targetFps &&
        a.renderScale == b.renderScale &&
        a.enableAnim == b.enableAnim &&
        a.enableParticles == b.enableParticles &&
        a.useRealTime == b.useRealTime &&
        a.simTime == b.simTime &&
        a.simMonth == b.simMonth;
  }

  void _update(SunriseConfig newConfig) {
    setState(() {
      _config = newConfig;
      _selectedPreset = _detectPreset(newConfig);
    });
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: const Color(0xFFE7B86B)),
              const SizedBox(width: 10),
              Text(
                '晨曦流光 设置',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 性能预设
          Text(
            '⚡ 性能模式',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PerformancePreset.values.map((preset) {
              final isSelected = _selectedPreset == preset;
              return ChoiceChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(preset.label),
                    Text(
                      preset.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        color: isSelected
                            ? const Color(0xFFE7B86B)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  _update(preset.apply(widget.config));
                },
                selectedColor: const Color(0xFF1B2432),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE7B86B) : Colors.white,
                  fontWeight: isSelected ? FontWeight.w700 : null,
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFE7B86B)
                      : const Color(0xFF293649),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 视觉效果
          Text(
            '🎨 视觉效果',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: '流动速度',
            value: _config.flowSpeed,
            min: 0.1,
            max: 5.0,
            divisions: 49,
            valueDisplay: _config.flowSpeed.toStringAsFixed(1),
            onChanged: (v) => _update(_config.copyWith(flowSpeed: v)),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '波浪幅度',
            value: _config.waveAmp,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            valueDisplay: _config.waveAmp.toStringAsFixed(2),
            onChanged: (v) => _update(_config.copyWith(waveAmp: v)),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '粒子数量',
            value: _config.particleCount.toDouble(),
            min: 20,
            max: 150,
            divisions: 130,
            valueDisplay: '${_config.particleCount}',
            onChanged: (v) =>
                _update(_config.copyWith(particleCount: v.round())),
          ),
          const SizedBox(height: 24),

          // 时间控制
          Text(
            '🕐 时间设置',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _config.useRealTime,
            contentPadding: EdgeInsets.zero,
            title: const Text('使用实时时间'),
            subtitle: Text(
              _config.useRealTime
                  ? '当前跟随系统时间自动变化'
                  : '模拟时间: ${_config.simTime.toStringAsFixed(1)}h (${_monthNames[_config.simMonth]})',
            ),
            onChanged: (v) => _update(_config.copyWith(useRealTime: v)),
          ),
          if (!_config.useRealTime) ...[
            const SizedBox(height: 8),
            _SliderRow(
              label: '模拟时间',
              value: _config.simTime,
              min: 0.0,
              max: 24.0,
              divisions: 480,
              valueDisplay: '${_config.simTime.toStringAsFixed(1)}h',
              onChanged: (v) =>
                  _update(_config.copyWith(simTime: v, useRealTime: false)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('模拟月份', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                DropdownButton<int>(
                  value: _config.simMonth,
                  dropdownColor: const Color(0xFF182230),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(value: i, child: Text('${i + 1}月')),
                  ),
                  onChanged: (v) {
                    if (v != null) {
                      _update(
                        _config.copyWith(simMonth: v, useRealTime: false),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // 性能微调
          Text(
            '🔧 性能微调',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: '目标帧率',
            value: _config.targetFps.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            valueDisplay: '${_config.targetFps}fps',
            onChanged: (v) => _update(_config.copyWith(targetFps: v.round())),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: '渲染分辨率',
            value: _config.renderScale * 100,
            min: 25,
            max: 100,
            divisions: 15,
            valueDisplay: '${(_config.renderScale * 100).round()}%',
            onChanged: (v) => _update(_config.copyWith(renderScale: v / 100)),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _config.enableAnim,
            contentPadding: EdgeInsets.zero,
            title: const Text('启用动态效果'),
            subtitle: const Text('关闭后停止波浪和光晕动画'),
            onChanged: (v) => _update(_config.copyWith(enableAnim: v)),
          ),
          SwitchListTile.adaptive(
            value: _config.enableParticles,
            contentPadding: EdgeInsets.zero,
            title: const Text('启用粒子效果'),
            subtitle: const Text('关闭后停止星空粒子'),
            onChanged: (v) => _update(_config.copyWith(enableParticles: v)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static const _monthNames = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFAEB7C5)),
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
