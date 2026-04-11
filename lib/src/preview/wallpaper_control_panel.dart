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

  const WallpaperConfig({
    this.flowSpeed = 5.0,
    this.waveAmp = 0.7,
    this.cssBlur = 0.0,
    this.useRealTime = true,
    this.simTime,
    this.simMonth,
  });

  WallpaperConfig copyWith({
    double? flowSpeed,
    double? waveAmp,
    double? cssBlur,
    bool? useRealTime,
    double? simTime,
    int? simMonth,
  }) {
    return WallpaperConfig(
      flowSpeed: flowSpeed ?? this.flowSpeed,
      waveAmp: waveAmp ?? this.waveAmp,
      cssBlur: cssBlur ?? this.cssBlur,
      useRealTime: useRealTime ?? this.useRealTime,
      simTime: simTime ?? this.simTime,
      simMonth: simMonth ?? this.simMonth,
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
          const SizedBox(height: 14),

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
