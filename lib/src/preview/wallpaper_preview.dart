import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/wallpaper_source.dart';
import 'media_preview.dart';

class WallpaperPreview extends StatefulWidget {
  const WallpaperPreview({
    super.key,
    this.htmlContent,
    this.wallpaper,
    this.configNotifier,
    this.showSettingsButton = false,
    this.onSettingsTap,
  }) : assert(htmlContent != null || wallpaper != null, 
             'Either htmlContent or wallpaper must be provided');

  final String? htmlContent;
  final WallpaperSource? wallpaper;

  /// 可选：通过 ValueNotifier 传递配置变化
  final ValueNotifier<Map<String, dynamic>>? configNotifier;

  /// 是否显示设置按钮
  final bool showSettingsButton;

  /// 设置按钮点击回调
  final VoidCallback? onSettingsTap;

  @override
  State<WallpaperPreview> createState() => _WallpaperPreviewState();
}

class _WallpaperPreviewState extends State<WallpaperPreview> {
  Object? _controller;

  WallpaperSource? get _wallpaper => widget.wallpaper;
  
  String get _htmlContent {
    if (widget.htmlContent != null) return widget.htmlContent!;
    if (_wallpaper?.htmlContent != null) return _wallpaper!.htmlContent!;
    return '';
  }

  @override
  void initState() {
    super.initState();
    widget.configNotifier?.addListener(_onConfigChanged);
  }

  @override
  void didUpdateWidget(covariant WallpaperPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configNotifier != widget.configNotifier) {
      oldWidget.configNotifier?.removeListener(_onConfigChanged);
      widget.configNotifier?.addListener(_onConfigChanged);
    }
  }

  @override
  void dispose() {
    widget.configNotifier?.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    final config = widget.configNotifier?.value;
    if (config != null && _controller != null) {
      _sendConfig(config);
    }
  }

  void _sendConfig(Map<String, dynamic> config) {
    final json = jsonEncode(config);
    // 转义单引号防止 JS 字符串断裂
    final escapedJson = json.replaceAll("'", "\\'");
    final controller = _controller;
    if (controller is WebviewController) {
      // Windows WebView2
      final script =
          'try{if(window.setWallpaperConfig){window.setWallpaperConfig(JSON.parse(\'$escapedJson\'));}}catch(e){console.error(e);}';
      unawaited(controller.executeScript(script));
    } else if (controller is WebViewController) {
      // Android WebView
      final script =
          'try{if(window.setWallpaperConfig){window.setWallpaperConfig(JSON.parse(\'$escapedJson\'));}}catch(e){console.error(e);}';
      unawaited(controller.runJavaScript(script));
    }
  }

  void _setController(Object c) {
    _controller = c;
    // 如果有初始配置，立即发送
    final config = widget.configNotifier?.value;
    if (config != null) {
      _sendConfig(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRunningUnderTest()) {
      return const _PreviewPlaceholder(
        title: 'Preview disabled in tests',
        subtitle: 'Widget tests do not host native WebView surfaces.',
      );
    }

    // 如果是图片/视频/GIF，使用媒体预览组件
    if (_wallpaper != null && 
        (_wallpaper!.isImage || _wallpaper!.isVideo || _wallpaper!.isGif)) {
      return MediaPreview(wallpaper: _wallpaper!);
    }

    if (Platform.isWindows) {
      return WindowsWallpaperPreview(
        htmlContent: _htmlContent,
        onControllerReady: _setController,
        showSettingsButton: widget.showSettingsButton,
        onSettingsTap: widget.onSettingsTap,
      );
    }

    if (Platform.isAndroid) {
      return AndroidWallpaperPreview(
        htmlContent: _htmlContent,
        onControllerReady: _setController,
        showSettingsButton: widget.showSettingsButton,
        onSettingsTap: widget.onSettingsTap,
      );
    }

    return const _PreviewPlaceholder(
      title: 'Unsupported platform',
      subtitle: 'This preview currently targets Windows and Android.',
    );
  }

  bool _isRunningUnderTest() {
    return Platform.environment.containsKey('FLUTTER_TEST');
  }
}

class WindowsWallpaperPreview extends StatefulWidget {
  const WindowsWallpaperPreview({
    super.key,
    required this.htmlContent,
    this.onControllerReady,
    this.showSettingsButton = false,
    this.onSettingsTap,
  });

  final String htmlContent;
  final void Function(WebviewController controller)? onControllerReady;
  final bool showSettingsButton;
  final VoidCallback? onSettingsTap;

  @override
  State<WindowsWallpaperPreview> createState() =>
      _WindowsWallpaperPreviewState();
}

class _WindowsWallpaperPreviewState extends State<WindowsWallpaperPreview> {
  final WebviewController _controller = WebviewController();

  bool _isReady = false;
  bool _isRuntimeMissing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        if (!mounted) return;
        setState(() => _isRuntimeMissing = true);
        return;
      }

      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadStringContent(widget.htmlContent);

      if (!mounted) return;
      setState(() => _isReady = true);
      widget.onControllerReady?.call(_controller);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${error.code}: ${error.message ?? 'Unknown error'}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  @override
  void didUpdateWidget(covariant WindowsWallpaperPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isReady && oldWidget.htmlContent != widget.htmlContent) {
      unawaited(_controller.loadStringContent(widget.htmlContent));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRuntimeMissing) {
      return const _PreviewPlaceholder(
        title: 'WebView2 runtime missing',
        subtitle: '请先安装 Microsoft Edge WebView2 Runtime。',
      );
    }

    if (_errorMessage != null) {
      return _PreviewPlaceholder(
        title: 'Windows preview failed',
        subtitle: _errorMessage!,
      );
    }

    if (!_isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Webview(_controller),
        if (widget.showSettingsButton)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onSettingsTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xB3111821),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334154)),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFE7B86B),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }
}

class AndroidWallpaperPreview extends StatefulWidget {
  const AndroidWallpaperPreview({
    super.key,
    required this.htmlContent,
    this.onControllerReady,
    this.showSettingsButton = false,
    this.onSettingsTap,
  });

  final String htmlContent;
  final void Function(WebViewController controller)? onControllerReady;
  final bool showSettingsButton;
  final VoidCallback? onSettingsTap;

  @override
  State<AndroidWallpaperPreview> createState() =>
      _AndroidWallpaperPreviewState();
}

class _AndroidWallpaperPreviewState extends State<AndroidWallpaperPreview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);
    unawaited(_controller.loadHtmlString(widget.htmlContent));
    widget.onControllerReady?.call(_controller);
  }

  @override
  void didUpdateWidget(covariant AndroidWallpaperPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      unawaited(_controller.loadHtmlString(widget.htmlContent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (widget.showSettingsButton)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onSettingsTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xB3111821),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334154)),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFE7B86B),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF19161F), Color(0xFF0D1118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.desktop_windows_rounded,
                  size: 42,
                  color: Color(0xFFE7B86B),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB8C1CF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
