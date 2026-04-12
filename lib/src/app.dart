import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'models/app_settings.dart';
import 'models/wallpaper_source.dart';
import 'preview/wallpaper_preview.dart';
import 'preview/wallpaper_control_panel.dart';
import 'preview/sunrise_settings.dart';
export 'preview/wallpaper_control_panel.dart' show WallpaperConfig;
import 'services/android_wallpaper_bridge.dart';
import 'services/app_settings_store.dart';
import 'services/desktop_wallpaper_bridge.dart';
import 'services/wallpaper_catalog.dart';
import 'services/system_info_service.dart';

class HtmlWallpaperApp extends StatelessWidget {
  const HtmlWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1017),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE7B86B),
        brightness: Brightness.dark,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'HTML Wallpaper',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const WallpaperHomePage(),
    );
  }
}

class WallpaperHomePage extends StatefulWidget {
  const WallpaperHomePage({super.key});

  @override
  State<WallpaperHomePage> createState() => _WallpaperHomePageState();
}

class _WallpaperHomePageState extends State<WallpaperHomePage>
    with WidgetsBindingObserver {
  final WallpaperCatalog _catalog = const WallpaperCatalog();

  List<WallpaperSource> _builtInWallpapers = const [];
  WallpaperSource? _selectedWallpaper;
  WallpaperSource? _customWallpaper;
  AppSettingsStore? _settingsStore;
  AppSettings _settings = const AppSettings.defaults();
  bool _launchAtStartup = false;
  bool _isLoading = true;
  bool _isPickingFile = false;
  bool _isUpdatingStartup = false;
  bool _isUpdatingAndroidDynamicColors = false;
  bool _isUpdatingAndroidBootAutoStart = false;
  bool _isUpdatingAndroidRenderConfig = false;
  bool _autoRestoreTriggered = false;
  bool _pendingAndroidWallpaperCheck = false;
  bool _androidDynamicColorsEnabled = true;
  bool _androidAutoStartOnBootEnabled = false;
  bool _androidRenderScaleEnabled = false;
  double _androidRenderScale = 0.5;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadInitialState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid) {
      return;
    }
    if (state == AppLifecycleState.resumed && _pendingAndroidWallpaperCheck) {
      _pendingAndroidWallpaperCheck = false;
      unawaited(_checkAndroidWallpaperApplied());
    }
  }

  Future<void> _loadInitialState() async {
    try {
      final settingsStore = await AppSettingsStore.create();
      final persistedSettings = await settingsStore.load();
      final wallpapers = await _catalog.loadBundledWallpapers();

      WallpaperSource? customWallpaper;
      if (persistedSettings.lastCustomWallpaperPath case final String path) {
        customWallpaper = await _catalog.loadWallpaperFromPath(path);
      }

      final allWallpapers = [
        ...wallpapers,
        ...?(customWallpaper == null ? null : [customWallpaper]),
      ];

      final selectedWallpaper =
          allWallpapers
              .where(
                (wallpaper) =>
                    wallpaper.id == persistedSettings.lastSelectedWallpaperId,
              )
              .firstOrNull ??
          allWallpapers.firstOrNull;

      final launchAtStartup = Platform.isWindows
          ? await DesktopWallpaperBridge.getLaunchAtStartup()
          : false;
      final androidDynamicColorsEnabled = Platform.isAndroid
          ? await AndroidWallpaperBridge.getDynamicColorsEnabled()
          : true;
      final androidAutoStartOnBootEnabled = Platform.isAndroid
          ? await AndroidWallpaperBridge.getAutoStartOnBootEnabled()
          : false;
      final androidRenderConfig = Platform.isAndroid
          ? await AndroidWallpaperBridge.getRenderConfig()
          : AndroidRenderConfig.defaults;

      if (!mounted) {
        return;
      }

      setState(() {
        _settingsStore = settingsStore;
        _settings = persistedSettings.copyWith(
          lastCustomWallpaperPath: customWallpaper?.filePath,
          clearLastCustomWallpaperPath:
              persistedSettings.lastCustomWallpaperPath != null &&
              customWallpaper == null,
        );
        _builtInWallpapers = wallpapers;
        _customWallpaper = customWallpaper;
        _selectedWallpaper = selectedWallpaper;
        _launchAtStartup = launchAtStartup;
        _androidDynamicColorsEnabled = androidDynamicColorsEnabled;
        _androidAutoStartOnBootEnabled = androidAutoStartOnBootEnabled;
        _androidRenderScaleEnabled = androidRenderConfig.enabled;
        _androidRenderScale = androidRenderConfig.scale;
        _isLoading = false;
      });

      if (_settings != persistedSettings) {
        await settingsStore.save(_settings);
      }

      if (Platform.isWindows &&
          _settings.autoRestoreWallpaperOnLaunch &&
          selectedWallpaper != null &&
          !_autoRestoreTriggered) {
        _autoRestoreTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_openWallpaperMode());
          }
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _persistSettings() async {
    final store = _settingsStore;
    if (store == null) {
      return;
    }
    await store.save(_settings);
  }

  Future<void> _selectWallpaper(WallpaperSource wallpaper) async {
    setState(() {
      _selectedWallpaper = wallpaper;
      _settings = _settings.copyWith(
        lastSelectedWallpaperId: wallpaper.id,
        lastCustomWallpaperPath: _customWallpaper?.filePath,
      );
    });
    await _persistSettings();
  }

  Future<void> _pickCustomWallpaper() async {
    setState(() {
      _isPickingFile = true;
    });

    try {
      final wallpaper = await _catalog.pickCustomWallpaper();
      if (!mounted || wallpaper == null) {
        return;
      }
      setState(() {
        _customWallpaper = wallpaper;
        _selectedWallpaper = wallpaper;
        _settings = _settings.copyWith(
          lastSelectedWallpaperId: wallpaper.id,
          lastCustomWallpaperPath: wallpaper.filePath,
        );
      });
      await _persistSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载 HTML 失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _setAutoRestoreWallpaperOnLaunch(bool enabled) async {
    setState(() {
      _settings = _settings.copyWith(autoRestoreWallpaperOnLaunch: enabled);
    });
    await _persistSettings();
  }

  Future<void> _setLaunchAtStartup(bool enabled) async {
    setState(() {
      _isUpdatingStartup = true;
    });

    try {
      final applied = await DesktopWallpaperBridge.setLaunchAtStartup(enabled);
      if (!mounted) {
        return;
      }
      setState(() {
        _launchAtStartup = applied;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(applied ? '已更新开机自启动。' : '开机自启动设置失败。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('设置开机自启动失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStartup = false;
        });
      }
    }
  }

  Future<void> _setAndroidDynamicColorsEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }

    final previous = _androidDynamicColorsEnabled;
    setState(() {
      _isUpdatingAndroidDynamicColors = true;
      _androidDynamicColorsEnabled = enabled;
    });

    try {
      final updated = await AndroidWallpaperBridge.setDynamicColorsEnabled(
        enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _androidDynamicColorsEnabled = updated ? enabled : previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated ? '已更新安卓动态取色设置。' : '更新动态取色设置失败。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _androidDynamicColorsEnabled = previous;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新动态取色设置失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAndroidDynamicColors = false;
        });
      }
    }
  }

  Future<void> _setAndroidAutoStartOnBootEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }

    final previous = _androidAutoStartOnBootEnabled;
    setState(() {
      _isUpdatingAndroidBootAutoStart = true;
      _androidAutoStartOnBootEnabled = enabled;
    });

    try {
      final updated = await AndroidWallpaperBridge.setAutoStartOnBootEnabled(
        enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _androidAutoStartOnBootEnabled = updated ? enabled : previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated ? '已更新安卓开机自启动设置。' : '更新开机自启动设置失败。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _androidAutoStartOnBootEnabled = previous;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新开机自启动设置失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAndroidBootAutoStart = false;
        });
      }
    }
  }

  Future<void> _setAndroidRenderConfig({
    bool? enabled,
    double? scale,
    bool showSnackbar = true,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    final nextEnabled = enabled ?? _androidRenderScaleEnabled;
    final nextScale = (scale ?? _androidRenderScale)
        .clamp(0.25, 1.0)
        .toDouble();
    final previousEnabled = _androidRenderScaleEnabled;
    final previousScale = _androidRenderScale;
    setState(() {
      _isUpdatingAndroidRenderConfig = true;
      _androidRenderScaleEnabled = nextEnabled;
      _androidRenderScale = nextScale;
    });

    try {
      final updated = await AndroidWallpaperBridge.setRenderConfig(
        enabled: nextEnabled,
        scale: nextScale,
      );
      if (!mounted) {
        return;
      }
      if (!updated) {
        setState(() {
          _androidRenderScaleEnabled = previousEnabled;
          _androidRenderScale = previousScale;
        });
      }
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updated ? '已更新安卓渲染分辨率设置。' : '更新渲染分辨率设置失败。')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _androidRenderScaleEnabled = previousEnabled;
        _androidRenderScale = previousScale;
      });
      if (showSnackbar) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新渲染分辨率设置失败: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAndroidRenderConfig = false;
        });
      }
    }
  }

  Future<void> _openWallpaperMode() async {
    final wallpaper = _selectedWallpaper;
    if (wallpaper == null || !Platform.isWindows) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WallpaperModePage(wallpaper: wallpaper),
      ),
    );
  }

  Future<void> _applySelectedWallpaper() async {
    final wallpaper = _selectedWallpaper;
    if (wallpaper == null) {
      return;
    }

    try {
      if (Platform.isWindows) {
        await _openWallpaperMode();
        return;
      }

      if (Platform.isAndroid) {
        final opened = await AndroidWallpaperBridge.applyWallpaper(wallpaper);
        if (!mounted) {
          return;
        }
        if (opened) {
          _pendingAndroidWallpaperCheck = true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? '已打开系统动态壁纸设置页。小米机型请在列表中手动选择并应用 HTML Wallpaper。'
                  : '打开动态壁纸设置页失败。',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('应用壁纸失败: $error')));
    }
  }

  Future<void> _openAndroidWallpaperSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final opened = await AndroidWallpaperBridge.openWallpaperPicker();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(opened ? '已打开系统动态壁纸设置页。' : '打开动态壁纸设置页失败。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开动态壁纸设置页失败: $error')));
    }
  }

  Future<void> _checkAndroidWallpaperApplied() async {
    try {
      final active = await AndroidWallpaperBridge.isWallpaperActive();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? '已成功应用 HTML Wallpaper。'
                : '系统未应用当前动态壁纸。请在列表中手动选择并应用 HTML Wallpaper。',
          ),
        ),
      );
    } catch (_) {
      // Ignore state check failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111821), Color(0xFF090C12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 980;
                    final previewHeight = (constraints.maxHeight * 0.42).clamp(
                      240.0,
                      420.0,
                    );
                    final sidebar = _WallpaperSidebar(
                      wallpapers: [
                        ..._builtInWallpapers,
                        ...?(_customWallpaper == null
                            ? null
                            : [_customWallpaper!]),
                      ],
                      selectedWallpaper: _selectedWallpaper,
                      isPickingFile: _isPickingFile,
                      launchAtStartup: _launchAtStartup,
                      autoRestoreWallpaperOnLaunch:
                          _settings.autoRestoreWallpaperOnLaunch,
                      isUpdatingStartup: _isUpdatingStartup,
                      isUpdatingAndroidDynamicColors:
                          _isUpdatingAndroidDynamicColors,
                      isUpdatingAndroidBootAutoStart:
                          _isUpdatingAndroidBootAutoStart,
                      isUpdatingAndroidRenderConfig:
                          _isUpdatingAndroidRenderConfig,
                      androidDynamicColorsEnabled: _androidDynamicColorsEnabled,
                      androidAutoStartOnBootEnabled:
                          _androidAutoStartOnBootEnabled,
                      androidRenderScaleEnabled: _androidRenderScaleEnabled,
                      androidRenderScale: _androidRenderScale,
                      enableInternalScroll: !compact,
                      onSelect: _selectWallpaper,
                      onPickCustom: _pickCustomWallpaper,
                      onLaunchAtStartupChanged: Platform.isWindows
                          ? _setLaunchAtStartup
                          : null,
                      onAutoRestoreWallpaperChanged:
                          _setAutoRestoreWallpaperOnLaunch,
                      onAndroidDynamicColorsChanged:
                          _setAndroidDynamicColorsEnabled,
                      onAndroidAutoStartOnBootChanged:
                          _setAndroidAutoStartOnBootEnabled,
                      onAndroidRenderScaleEnabledChanged: (enabled) {
                        unawaited(
                          _setAndroidRenderConfig(
                            enabled: enabled,
                            showSnackbar: true,
                          ),
                        );
                      },
                      onAndroidRenderScaleChanged: (scale) {
                        unawaited(
                          _setAndroidRenderConfig(
                            scale: scale,
                            showSnackbar: false,
                          ),
                        );
                      },
                    );

                    final preview = _PreviewPanel(
                      wallpaper: _selectedWallpaper,
                      onApplyWallpaper: _applySelectedWallpaper,
                      onOpenAndroidWallpaperSettings:
                          _openAndroidWallpaperSettings,
                    );

                    if (compact) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            SizedBox(height: previewHeight, child: preview),
                            const SizedBox(height: 12),
                            sidebar,
                          ],
                        ),
                      );
                    }

                    return Row(
                      children: [
                        SizedBox(width: 360, child: sidebar),
                        const SizedBox(width: 18),
                        Expanded(child: preview),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _WallpaperSidebar extends StatelessWidget {
  const _WallpaperSidebar({
    required this.wallpapers,
    required this.selectedWallpaper,
    required this.isPickingFile,
    required this.launchAtStartup,
    required this.autoRestoreWallpaperOnLaunch,
    required this.isUpdatingStartup,
    required this.isUpdatingAndroidDynamicColors,
    required this.isUpdatingAndroidBootAutoStart,
    required this.isUpdatingAndroidRenderConfig,
    required this.androidDynamicColorsEnabled,
    required this.androidAutoStartOnBootEnabled,
    required this.androidRenderScaleEnabled,
    required this.androidRenderScale,
    required this.onSelect,
    required this.onPickCustom,
    required this.onAutoRestoreWallpaperChanged,
    required this.onAndroidDynamicColorsChanged,
    required this.onAndroidAutoStartOnBootChanged,
    required this.onAndroidRenderScaleEnabledChanged,
    required this.onAndroidRenderScaleChanged,
    this.enableInternalScroll = true,
    this.onLaunchAtStartupChanged,
  });

  final List<WallpaperSource> wallpapers;
  final WallpaperSource? selectedWallpaper;
  final bool isPickingFile;
  final bool launchAtStartup;
  final bool autoRestoreWallpaperOnLaunch;
  final bool isUpdatingStartup;
  final bool isUpdatingAndroidDynamicColors;
  final bool isUpdatingAndroidBootAutoStart;
  final bool isUpdatingAndroidRenderConfig;
  final bool androidDynamicColorsEnabled;
  final bool androidAutoStartOnBootEnabled;
  final bool androidRenderScaleEnabled;
  final double androidRenderScale;
  final ValueChanged<WallpaperSource> onSelect;
  final Future<void> Function() onPickCustom;
  final ValueChanged<bool>? onLaunchAtStartupChanged;
  final ValueChanged<bool> onAutoRestoreWallpaperChanged;
  final ValueChanged<bool> onAndroidDynamicColorsChanged;
  final ValueChanged<bool> onAndroidAutoStartOnBootChanged;
  final ValueChanged<bool> onAndroidRenderScaleEnabledChanged;
  final ValueChanged<double> onAndroidRenderScaleChanged;
  final bool enableInternalScroll;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.88),
        border: Border.all(color: const Color(0xFF263040)),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HTML Wallpaper',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '导入或选择一个 HTML 文件，在当前平台预览后直接应用到桌面或动态壁纸服务。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFAEB7C5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: isPickingFile ? null : onPickCustom,
              icon: isPickingFile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('导入 HTML 文件'),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              launchAtStartup: launchAtStartup,
              autoRestoreWallpaperOnLaunch: autoRestoreWallpaperOnLaunch,
              isUpdatingStartup: isUpdatingStartup,
              isUpdatingAndroidDynamicColors: isUpdatingAndroidDynamicColors,
              isUpdatingAndroidBootAutoStart: isUpdatingAndroidBootAutoStart,
              isUpdatingAndroidRenderConfig: isUpdatingAndroidRenderConfig,
              androidDynamicColorsEnabled: androidDynamicColorsEnabled,
              androidAutoStartOnBootEnabled: androidAutoStartOnBootEnabled,
              androidRenderScaleEnabled: androidRenderScaleEnabled,
              androidRenderScale: androidRenderScale,
              onLaunchAtStartupChanged: onLaunchAtStartupChanged,
              onAutoRestoreWallpaperChanged: onAutoRestoreWallpaperChanged,
              onAndroidDynamicColorsChanged: onAndroidDynamicColorsChanged,
              onAndroidAutoStartOnBootChanged: onAndroidAutoStartOnBootChanged,
              onAndroidRenderScaleEnabledChanged:
                  onAndroidRenderScaleEnabledChanged,
              onAndroidRenderScaleChanged: onAndroidRenderScaleChanged,
            ),
            const SizedBox(height: 18),
            if (enableInternalScroll)
              Expanded(
                child: ListView.separated(
                  itemCount: wallpapers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final wallpaper = wallpapers[index];
                    final selected = wallpaper.id == selectedWallpaper?.id;
                    return _WallpaperCard(
                      wallpaper: wallpaper,
                      selected: selected,
                      onTap: () => onSelect(wallpaper),
                    );
                  },
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wallpapers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final wallpaper = wallpapers[index];
                  final selected = wallpaper.id == selectedWallpaper?.id;
                  return _WallpaperCard(
                    wallpaper: wallpaper,
                    selected: selected,
                    onTap: () => onSelect(wallpaper),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.launchAtStartup,
    required this.autoRestoreWallpaperOnLaunch,
    required this.isUpdatingStartup,
    required this.isUpdatingAndroidDynamicColors,
    required this.isUpdatingAndroidBootAutoStart,
    required this.isUpdatingAndroidRenderConfig,
    required this.androidDynamicColorsEnabled,
    required this.androidAutoStartOnBootEnabled,
    required this.androidRenderScaleEnabled,
    required this.androidRenderScale,
    required this.onAutoRestoreWallpaperChanged,
    required this.onAndroidDynamicColorsChanged,
    required this.onAndroidAutoStartOnBootChanged,
    required this.onAndroidRenderScaleEnabledChanged,
    required this.onAndroidRenderScaleChanged,
    this.onLaunchAtStartupChanged,
  });

  final bool launchAtStartup;
  final bool autoRestoreWallpaperOnLaunch;
  final bool isUpdatingStartup;
  final bool isUpdatingAndroidDynamicColors;
  final bool isUpdatingAndroidBootAutoStart;
  final bool isUpdatingAndroidRenderConfig;
  final bool androidDynamicColorsEnabled;
  final bool androidAutoStartOnBootEnabled;
  final bool androidRenderScaleEnabled;
  final double androidRenderScale;
  final ValueChanged<bool>? onLaunchAtStartupChanged;
  final ValueChanged<bool> onAutoRestoreWallpaperChanged;
  final ValueChanged<bool> onAndroidDynamicColorsChanged;
  final ValueChanged<bool> onAndroidAutoStartOnBootChanged;
  final ValueChanged<bool> onAndroidRenderScaleEnabledChanged;
  final ValueChanged<double> onAndroidRenderScaleChanged;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121B27),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF293649)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android 说明',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '应用后会打开系统动态壁纸设置页，不需要 root。当前版本优先支持单个 HTML 文件本体，若页面依赖同目录脚本或图片，建议先内联资源。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A1B6),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: androidAutoStartOnBootEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('开机自动启动应用'),
              subtitle: Text(
                isUpdatingAndroidBootAutoStart
                    ? '正在更新设置...'
                    : '设备重启后自动拉起应用，并尝试恢复动态壁纸状态。',
              ),
              onChanged: isUpdatingAndroidBootAutoStart
                  ? null
                  : onAndroidAutoStartOnBootChanged,
            ),
            SwitchListTile.adaptive(
              value: androidDynamicColorsEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 Android 动态取色'),
              subtitle: Text(
                isUpdatingAndroidDynamicColors
                    ? '正在更新设置...'
                    : '从壁纸 HTML 按时间读取主色，供系统动态配色使用（Android 12+ 更明显）。',
              ),
              onChanged: isUpdatingAndroidDynamicColors
                  ? null
                  : onAndroidDynamicColorsChanged,
            ),
            SwitchListTile.adaptive(
              value: androidRenderScaleEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('降低渲染分辨率'),
              subtitle: Text(
                androidRenderScaleEnabled
                    ? '当前渲染分辨率: ${(androidRenderScale * 100).toStringAsFixed(0)}%'
                    : '关闭后使用屏幕原始分辨率渲染。',
              ),
              onChanged: isUpdatingAndroidRenderConfig
                  ? null
                  : onAndroidRenderScaleEnabledChanged,
            ),
            if (androidRenderScaleEnabled) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '渲染比例',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFAEB7C5),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(androidRenderScale * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFE7B86B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: androidRenderScale,
                min: 0.25,
                max: 1.0,
                divisions: 15,
                onChanged: isUpdatingAndroidRenderConfig
                    ? null
                    : onAndroidRenderScaleChanged,
              ),
              Text(
                '建议先用 50%（接近 1/2 分辨率），明显降低卡顿。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A1B6)),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121B27),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF293649)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实用功能',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '这些设置只影响当前机器的 Windows 端行为。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A1B6),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: autoRestoreWallpaperOnLaunch,
            contentPadding: EdgeInsets.zero,
            title: const Text('启动后自动恢复壁纸'),
            subtitle: const Text('记住上次选择的壁纸，并在打开应用时自动进入壁纸模式。'),
            onChanged: onAutoRestoreWallpaperChanged,
          ),
          SwitchListTile.adaptive(
            value: launchAtStartup,
            contentPadding: EdgeInsets.zero,
            title: const Text('Windows 开机自启动'),
            subtitle: Text(isUpdatingStartup ? '正在更新注册表...' : '登录后自动启动本应用。'),
            onChanged: isUpdatingStartup ? null : onLaunchAtStartupChanged,
          ),
        ],
      ),
    );
  }
}

class _WallpaperCard extends StatelessWidget {
  const _WallpaperCard({
    required this.wallpaper,
    required this.selected,
    required this.onTap,
  });

  final WallpaperSource wallpaper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFE7B86B)
        : const Color(0xFF283243);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          color: selected
              ? const Color(0xFF1B2432)
              : const Color(0xFF111821).withValues(alpha: 0.8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x332A1A00),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  wallpaper.isCustomFile
                      ? Icons.file_present_rounded
                      : Icons.auto_awesome_rounded,
                  color: const Color(0xFFE7B86B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    wallpaper.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              wallpaper.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFAEB7C5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              wallpaper.originLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: const Color(0xFF788396)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    required this.wallpaper,
    required this.onApplyWallpaper,
    required this.onOpenAndroidWallpaperSettings,
  });

  final WallpaperSource? wallpaper;
  final Future<void> Function() onApplyWallpaper;
  final Future<void> Function() onOpenAndroidWallpaperSettings;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  final ValueNotifier<Map<String, dynamic>> _configNotifier =
      ValueNotifier<Map<String, dynamic>>({
        'flowSpeed': 5.0,
        'waveAmp': 0.7,
        'cssBlur': 0.0,
        'useRealTime': true,
      });

  SunriseConfig _sunriseConfig = const SunriseConfig();
  Timer? _configApplyHintHideTimer;
  bool _showConfigAppliedHint = false;
  
  // 系统信息服务
  final SystemInfoService _systemInfoService = SystemInfoService();
  Timer? _systemInfoTimer;

  bool get _isSunriseWallpaper => widget.wallpaper?.id == 'wallpaper3.html';

  @override
  void initState() {
    super.initState();
    // 启动系统信息定时更新
    _startSystemInfoUpdates();
  }

  @override
  void dispose() {
    _configApplyHintHideTimer?.cancel();
    _systemInfoTimer?.cancel();
    _configNotifier.dispose();
    super.dispose();
  }
  
  /// 启动系统信息定时更新
  void _startSystemInfoUpdates() {
    // 默认 5 秒更新一次，可以在设置中自定义
    const interval = Duration(seconds: 5);
    
    _systemInfoTimer = Timer.periodic(interval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final systemInfo = await _systemInfoService.getSystemInfo();
        _updateSystemInfo(systemInfo);
      } catch (e) {
        // 忽略系统信息获取失败
      }
    });
    
    // 立即获取一次
    _systemInfoService.getSystemInfo().then((info) {
      if (mounted) {
        _updateSystemInfo(info);
      }
    });
  }
  
  /// 更新系统信息到配置
  void _updateSystemInfo(SystemInfo info) {
    if (!mounted) return;
    
    final currentConfig = Map<String, dynamic>.from(_configNotifier.value);
    currentConfig.addAll(info.toJson());
    _configNotifier.value = currentConfig;
  }

  void _notifyConfigApplied() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showConfigAppliedHint = true;
    });
    _configApplyHintHideTimer?.cancel();
    _configApplyHintHideTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showConfigAppliedHint = false;
      });
    });
  }

  void _openControlPanel() {
    if (_isSunriseWallpaper) {
      // Windows 上 WebView 会拦截所有触摸/鼠标事件，用全屏路由覆盖
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFF111821),
            appBar: AppBar(
              title: const Text('晨曦流光 设置'),
              backgroundColor: const Color(0xFF111821),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            body: SunriseWallpaperSettings(
              config: _sunriseConfig,
              onConfigChanged: (cfg) {
                setState(() => _sunriseConfig = cfg);
                _sendSunriseConfig(cfg);
                _notifyConfigApplied();
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return PointerInterceptor(
            child: _ControlSheet(
              configNotifier: _configNotifier,
              onConfigChanged: _notifyConfigApplied,
            ),
          );
        },
      );
    }
  }

  void _sendSunriseConfig(SunriseConfig cfg) {
    _configNotifier.value = cfg.toJson();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallpaper = widget.wallpaper;
    final isWindows = Platform.isWindows;
    final isAndroid = Platform.isAndroid;
    final canApplyWallpaper =
        selectedWallpaper != null && (isWindows || isAndroid);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF091018).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF263040)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with settings button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedWallpaper?.title ?? 'No wallpaper selected',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFFE7B86B),
                  ),
                  tooltip: '调节参数',
                  onPressed: _openControlPanel,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isWindows
                  ? 'Windows 端已支持记住上次壁纸、启动自动恢复，以及登录后自启动。恢复设置页仍然使用系统托盘图标。'
                  : isAndroid
                  ? 'Android 端会把当前 HTML 写入应用内动态壁纸服务，并拉起系统设置页让你确认启用。这个流程不需要 root。'
                  : '当前平台只提供 HTML 预览。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFAEB7C5),
                height: 1.55,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _showConfigAppliedHint
                  ? Padding(
                      key: const ValueKey('config-applied-hint'),
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFFE7B86B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '参数已应用',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFFE7B86B),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(key: ValueKey('config-applied-hint-empty')),
            ),
            const SizedBox(height: 18),
            // Preview
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black),
                  child: selectedWallpaper == null
                      ? const Center(child: Text('请选择一个 HTML 壁纸'))
                      : WallpaperPreview(
                          key: ValueKey(selectedWallpaper.id),
                          htmlContent: selectedWallpaper.htmlContent,
                          configNotifier: _configNotifier,
                          showSettingsButton: _isSunriseWallpaper,
                          onSettingsTap: _openControlPanel,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: canApplyWallpaper ? widget.onApplyWallpaper : null,
                  icon: const Icon(Icons.wallpaper_rounded),
                  label: Text(
                    isWindows
                        ? '设为 Windows 壁纸'
                        : isAndroid
                        ? '设为安卓动态壁纸'
                        : '应用壁纸',
                  ),
                ),
                if (isWindows)
                  OutlinedButton.icon(
                    onPressed: selectedWallpaper == null
                        ? null
                        : widget.onApplyWallpaper,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('恢复上次壁纸模式'),
                  ),
                if (isAndroid)
                  OutlinedButton.icon(
                    onPressed: widget.onOpenAndroidWallpaperSettings,
                    icon: const Icon(Icons.settings_suggest_rounded),
                    label: const Text('打开系统壁纸设置'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlSheet extends StatelessWidget {
  const _ControlSheet({
    required this.configNotifier,
    required this.onConfigChanged,
  });

  final ValueNotifier<Map<String, dynamic>> configNotifier;
  final VoidCallback onConfigChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111821),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: configNotifier,
          builder: (context, configValue, _) {
            final config = WallpaperConfig(
              flowSpeed: configValue['flowSpeed'] ?? 5.0,
              waveAmp: configValue['waveAmp'] ?? 0.7,
              cssBlur: configValue['cssBlur'] ?? 0.0,
              useRealTime: configValue['useRealTime'] ?? true,
              simTime: configValue['simTime'],
              simMonth: configValue['simMonth'],
            );
            return WallpaperControlPanel(
              config: config,
              onConfigChanged: (cfg) {
                configNotifier.value = Map<String, dynamic>.from(
                  configNotifier.value,
                )..addAll(cfg.toJson());
                onConfigChanged();
              },
            );
          },
        ),
      ),
    );
  }
}

class WallpaperModePage extends StatefulWidget {
  const WallpaperModePage({super.key, required this.wallpaper});

  final WallpaperSource wallpaper;

  @override
  State<WallpaperModePage> createState() => _WallpaperModePageState();
}

class _WallpaperModePageState extends State<WallpaperModePage> {
  Timer? _attachedStatePoller;
  bool _isAttaching = true;
  bool _isAttached = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_enterWallpaperMode());
    _attachedStatePoller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshAttachedState()),
    );
  }

  Future<void> _enterWallpaperMode() async {
    try {
      final attached = await DesktopWallpaperBridge.attachToDesktop();
      final nativeStatus = await DesktopWallpaperBridge.getDesktopStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _isAttaching = false;
        _isAttached = attached;
        _errorMessage = attached ? null : (nativeStatus ?? '未能挂到桌面层。');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAttaching = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _refreshAttachedState() async {
    final attached = await DesktopWallpaperBridge.isAttached();
    final nativeStatus = await DesktopWallpaperBridge.getDesktopStatus();
    if (!mounted) {
      return;
    }
    if (attached != _isAttached) {
      setState(() {
        _isAttached = attached;
        if (!attached && nativeStatus != null && nativeStatus.isNotEmpty) {
          _errorMessage = nativeStatus;
        }
      });
    }
  }

  Future<void> _exitWallpaperMode() async {
    await DesktopWallpaperBridge.detachFromDesktop();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _attachedStatePoller?.cancel();
    if (_isAttached) {
      unawaited(DesktopWallpaperBridge.detachFromDesktop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = _isAttaching || !_isAttached || _errorMessage != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: WallpaperPreview(htmlContent: widget.wallpaper.htmlContent),
          ),
          if (showOverlay)
            Positioned(
              left: 24,
              top: 24,
              right: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB3111821),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334154)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Wrap(
                    runSpacing: 10,
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _exitWallpaperMode,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('返回设置页'),
                      ),
                      Text(
                        _isAttaching
                            ? '正在进入桌面壁纸模式...'
                            : _isAttached
                            ? '已挂到桌面图标后面，恢复设置页请用托盘图标或这里的按钮。'
                            : (_errorMessage ?? '未连接到桌面层。'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
