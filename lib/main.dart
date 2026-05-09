import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:webview_windows/webview_windows.dart';

import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: 初始化 WebView2 环境时传入 GPU 优化参数
  if (Platform.isWindows) {
    try {
      await WebviewController.initializeEnvironment(
        additionalArguments:
            '--disable-gpu-vsync '
            '--disable-features=GpuProcessHighPriorityWin,SmoothScrolling '
            '--disable-smooth-scrolling '
            '--disable-composited-antialiasing',
      );
    } catch (e) {
      // 环境可能已被初始化，忽略错误
    }
  }

  runApp(const HtmlWallpaperApp());
}
