import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

import '../config/viewer_config_notifier.dart';

enum _LoadingState { idle, loading, ready, error }

class ViewerScreen extends HookWidget {
  final List<String> pcdFiles;
  final ViewerConfigNotifier configNotifier;
  final NativeCameraController controller;

  const ViewerScreen({
    super.key,
    required this.pcdFiles,
    required this.configNotifier,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = useState(0);
    final isPlaying = useState(pcdFiles.length > 1);
    final loadingState = useState(_LoadingState.loading);
    final optimizationStats = useState<OptimizationStats?>(null);
    final errorMessage = useState<String?>(null);
    final playbackTimer = useRef<Timer?>(null);

    useEffect(() {
      playbackTimer.value?.cancel();
      if (!isPlaying.value || pcdFiles.length <= 1 || loadingState.value != _LoadingState.ready) {
        return null;
      }

      playbackTimer.value = Timer(
        const Duration(milliseconds: 33),
        () {
          loadingState.value = _LoadingState.loading;
          currentIndex.value = (currentIndex.value + 1) % pcdFiles.length;
        },
      );

      return () => playbackTimer.value?.cancel();
    }, [isPlaying.value, loadingState.value, currentIndex.value, pcdFiles.length]);

    return PopScope<NativeCameraController>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(controller);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(controller),
          ),
          title: Text(
            pcdFiles.length > 1
                ? '${currentIndex.value + 1}/${pcdFiles.length}'
                : pcdFiles[0].split('/').last,
          ),
          actions: [
            if (pcdFiles.length > 1)
              IconButton(
                icon: Icon(isPlaying.value ? Icons.pause : Icons.play_arrow),
                onPressed: () => isPlaying.value = !isPlaying.value,
              ),
          ],
        ),
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: configNotifier,
              builder: (context, _) => PcdView.fromFile(
                key: ValueKey(pcdFiles[currentIndex.value]),
                filePath: pcdFiles[currentIndex.value],
                config: configNotifier.config,
                controller: controller,
                onLoaded: (_) {
                  loadingState.value = _LoadingState.ready;
                  errorMessage.value = null;
                },
                onError: (error) {
                  loadingState.value = _LoadingState.error;
                  errorMessage.value = error;
                },
                onOptimized: (stats) {
                  optimizationStats.value = stats;
                },
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: _RendererModeCard(configNotifier: configNotifier),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: _PointSizeControl(configNotifier: configNotifier),
            ),
            // 底部状态栏
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _LoadingStatusBar(
                state: loadingState.value,
                errorMessage: errorMessage.value,
                stats: optimizationStats.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RendererModeCard extends StatelessWidget {
  final ViewerConfigNotifier configNotifier;

  const _RendererModeCard({required this.configNotifier});

  @override
  Widget build(BuildContext context) {
    final config = configNotifier.config;
    final isAndroidNative = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Card(
      color: Colors.black.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAndroidNative ? Icons.memory : Icons.layers,
                  size: 16,
                  color: isAndroidNative ? Colors.lightGreenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  isAndroidNative ? 'Android Native' : 'Fallback Renderer',
                  style: TextStyle(
                    color: isAndroidNative ? Colors.lightGreenAccent : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '点预算: ${config.performance.nativePointBudget > 0 ? config.performance.nativePointBudget : '不限制'}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              '渲染比例: ${config.performance.nativeRenderScale.toStringAsFixed(2)}x',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointSizeControl extends StatelessWidget {
  final ViewerConfigNotifier configNotifier;

  const _PointSizeControl({required this.configNotifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: configNotifier,
      builder: (context, _) {
        final size = configNotifier.config.pointSize;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: size < 10.0 ? () => configNotifier.updatePointSize(size + 0.5) : null,
                ),
                Text(size.toStringAsFixed(1)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: size > 1.0 ? () => configNotifier.updatePointSize(size - 0.5) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingStatusBar extends StatelessWidget {
  final _LoadingState state;
  final String? errorMessage;
  final OptimizationStats? stats;

  const _LoadingStatusBar({
    required this.state,
    this.errorMessage,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = state == _LoadingState.error
        ? Colors.red.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态文本
            Row(
              children: [
                _StatusIcon(state: state),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: state == _LoadingState.error ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (stats != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${_formatNumber(stats!.finalCount)} 点',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            // 不确定进度条（加载中显示动画，无假百分比）
            if (state == _LoadingState.loading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 4,
                ),
              ),
            ],
            // 错误信息
            if (state == _LoadingState.error && errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (state) {
      case _LoadingState.idle:
        return '等待加载';
      case _LoadingState.loading:
        return '正在解析点云...';
      case _LoadingState.ready:
        return stats != null
            ? '加载完成 · 减少 ${(stats!.reductionRatio * 100).toStringAsFixed(1)}%'
            : '加载完成';
      case _LoadingState.error:
        return '加载失败';
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class _StatusIcon extends StatelessWidget {
  final _LoadingState state;

  const _StatusIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _LoadingState.idle:
        return const Icon(Icons.hourglass_empty, color: Colors.white54, size: 16);
      case _LoadingState.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        );
      case _LoadingState.ready:
        return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16);
      case _LoadingState.error:
        return const Icon(Icons.error, color: Colors.white, size: 16);
    }
  }
}
