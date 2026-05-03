import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/wallpaper_source.dart';

/// 图片和视频壁纸预览组件
class MediaPreview extends StatefulWidget {
  const MediaPreview({
    super.key,
    required this.wallpaper,
  });

  final WallpaperSource wallpaper;

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.wallpaper.isVideo || widget.wallpaper.isGif) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaper.filePath != widget.wallpaper.filePath) {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      if (widget.wallpaper.isVideo || widget.wallpaper.isGif) {
        _initializeVideo();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.wallpaper.filePath == null) {
      setState(() {
        _errorMessage = '文件路径不存在';
      });
      return;
    }

    try {
      final controller = widget.wallpaper.isGif
          ? VideoPlayerController.file(
              File(widget.wallpaper.filePath!),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            )
          : VideoPlayerController.file(
              File(widget.wallpaper.filePath!),
            );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '视频加载失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 静态图片预览
    if (widget.wallpaper.isImage && widget.wallpaper.filePath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(widget.wallpaper.filePath!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '图片加载失败',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 图片信息标签
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    widget.wallpaper.fileExtension?.toUpperCase() ?? 'IMG',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 视频/GIF 预览
    if ((widget.wallpaper.isVideo || widget.wallpaper.isGif) &&
        _isVideoInitialized &&
        _videoController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // 视频控制按钮（可选，目前自动播放循环）
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          // 格式标签
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.wallpaper.isGif
                        ? Icons.gif_rounded
                        : Icons.videocam_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.wallpaper.fileExtension?.toUpperCase() ?? 'VIDEO',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 加载中状态
    if (widget.wallpaper.isVideo || widget.wallpaper.isGif) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    // 默认占位符
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_photo,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '不支持的媒体类型',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
