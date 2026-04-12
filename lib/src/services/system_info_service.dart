import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// 系统信息数据模型
class SystemInfo {
  final double? batteryLevel;        // 电池电量 0-100
  final bool? isCharging;            // 是否充电中
  final String? batteryState;        // 充电状态字符串
  final double? cpuUsage;            // CPU 使用率 (Windows)
  final double? totalMemory;         // 总内存 (MB)
  final double? usedMemory;          // 已用内存 (MB)
  final double? memoryUsagePercent;  // 内存使用率
  final String? wifiName;            // WiFi 名称
  final String? wifiIP;              // WiFi IP
  final String? networkType;         // 网络类型
  final DateTime timestamp;          // 数据采集时间

  const SystemInfo({
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
    required this.timestamp,
  });

  /// 转换为 JSON，用于传递给 HTML
  Map<String, dynamic> toJson() {
    return {
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'batteryState': batteryState,
      'cpuUsage': cpuUsage,
      'totalMemory': totalMemory,
      'usedMemory': usedMemory,
      'memoryUsagePercent': memoryUsagePercent,
      'wifiName': wifiName,
      'wifiIP': wifiIP,
      'networkType': networkType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 系统信息服务
/// 负责获取本机系统信息（电池、CPU、内存、网络等）
class SystemInfoService {
  final Battery _battery = Battery();
  final NetworkInfo _networkInfo = NetworkInfo();

  /// 获取完整的系统信息
  Future<SystemInfo> getSystemInfo() async {
    final info = SystemInfo(
      batteryLevel: await _getBatteryLevel(),
      isCharging: await _getIsCharging(),
      batteryState: await _getBatteryState(),
      cpuUsage: await _getCpuUsage(),
      totalMemory: await _getTotalMemory(),
      usedMemory: await _getUsedMemory(),
      memoryUsagePercent: await _getMemoryUsagePercent(),
      wifiName: await _getWifiName(),
      wifiIP: await _getWifiIP(),
      networkType: await _getNetworkType(),
      timestamp: DateTime.now(),
    );
    return info;
  }

  /// 获取电池电量 (0-100)
  Future<double?> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level.toDouble();
    } catch (e) {
      return null;
    }
  }

  /// 获取是否充电中
  Future<bool?> _getIsCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || 
             state == BatteryState.full;
    } catch (e) {
      return null;
    }
  }

  /// 获取电池状态字符串
  Future<String?> _getBatteryState() async {
    try {
      final state = await _battery.batteryState;
      switch (state) {
        case BatteryState.charging:
          return 'charging';
        case BatteryState.discharging:
          return 'discharging';
        case BatteryState.full:
          return 'full';
        case BatteryState.unknown:
          return 'unknown';
        case BatteryState.connectedNotCharging:
          return 'connected_not_charging';
      }
    } catch (e) {
      return null;
    }
  }

  /// 获取 CPU 使用率 (Windows 专用)
  Future<double?> _getCpuUsage() async {
    try {
      if (Platform.isWindows) {
        return await _getCpuUsageWindows();
      } else if (Platform.isAndroid) {
        return await _getCpuUsageAndroid();
      }
    } catch (e) {
      // CPU 信息获取失败
    }
    return null;
  }

  /// Windows CPU 使用率
  Future<double?> _getCpuUsageWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage'
      ]);
      if (result.exitCode == 0 && result.stdout != null) {
        final value = result.stdout.toString().trim();
        return double.tryParse(value);
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// Android CPU 使用率 (从 /proc/stat 读取)
  Future<double?> _getCpuUsageAndroid() async {
    try {
      // 简化实现：读取 /proc/stat 计算 CPU 使用率
      // 这里返回 null，实际可以采样两次 /proc/stat 计算差值
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取总内存 (MB)
  Future<double?> _getTotalMemory() async {
    try {
      if (Platform.isWindows) {
        return await _getTotalMemoryWindows();
      } else if (Platform.isAndroid) {
        return await _getTotalMemoryAndroid();
      }
    } catch (e) {
      // 内存信息获取失败
    }
    return null;
  }

  /// Windows 总内存
  Future<double?> _getTotalMemoryWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty TotalVisibleMemorySize) / 1024'
      ]);
      if (result.exitCode == 0 && result.stdout != null) {
        final value = result.stdout.toString().trim();
        return double.tryParse(value);
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// Android 总内存 (从 /proc/meminfo 读取)
  Future<double?> _getTotalMemoryAndroid() async {
    try {
      final result = await Process.run('cat', ['/proc/meminfo']);
      if (result.exitCode == 0 && result.stdout != null) {
        final output = result.stdout.toString();
        final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(output);
        if (match != null) {
          final kb = double.tryParse(match.group(1)!);
          return kb != null ? kb / 1024 : null; // 转换为 MB
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 获取已用内存 (MB)
  Future<double?> _getUsedMemory() async {
    try {
      if (Platform.isWindows) {
        return await _getUsedMemoryWindows();
      } else if (Platform.isAndroid) {
        return await _getUsedMemoryAndroid();
      }
    } catch (e) {
      // 内存信息获取失败
    }
    return null;
  }

  /// Windows 已用内存
  Future<double?> _getUsedMemoryWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '''
\$os = Get-CimInstance Win32_OperatingSystem;
(\$os.TotalVisibleMemorySize - \$os.FreePhysicalMemory) / 1024
'''
      ]);
      if (result.exitCode == 0 && result.stdout != null) {
        final value = result.stdout.toString().trim();
        return double.tryParse(value);
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// Android 已用内存
  Future<double?> _getUsedMemoryAndroid() async {
    try {
      final result = await Process.run('cat', ['/proc/meminfo']);
      if (result.exitCode == 0 && result.stdout != null) {
        final output = result.stdout.toString();
        final totalMatch = RegExp(r'MemTotal:\s+(\d+)').firstMatch(output);
        final availMatch = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(output);
        
        if (totalMatch != null && availMatch != null) {
          final total = double.tryParse(totalMatch.group(1)!);
          final avail = double.tryParse(availMatch.group(1)!);
          if (total != null && avail != null) {
            return (total - avail) / 1024; // 转换为 MB
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 获取内存使用率 (0-100)
  Future<double?> _getMemoryUsagePercent() async {
    try {
      final total = await _getTotalMemory();
      final used = await _getUsedMemory();
      if (total != null && used != null && total > 0) {
        return (used / total) * 100;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 获取 WiFi 名称
  Future<String?> _getWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      return null;
    }
  }

  /// 获取 WiFi IP
  Future<String?> _getWifiIP() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      return null;
    }
  }

  /// 获取网络类型
  Future<String?> _getNetworkType() async {
    try {
      final wifiName = await _getWifiName();
      if (wifiName != null) {
        return 'WiFi';
      }
      // Android 可以进一步判断 4G/5G
      if (Platform.isAndroid) {
        return await _getNetworkTypeAndroid();
      }
      return 'Unknown';
    } catch (e) {
      return null;
    }
  }

  /// Android 网络类型
  Future<String?> _getNetworkTypeAndroid() async {
    try {
      // 简化实现，可以结合 connectivity_plus 包获取详细信息
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 启动定时监听，持续更新系统信息
  Stream<SystemInfo> watchSystemInfo({Duration interval = const Duration(seconds: 1)}) {
    return Stream.periodic(interval, (_) => getSystemInfo()).asyncMap((future) => future);
  }
}
