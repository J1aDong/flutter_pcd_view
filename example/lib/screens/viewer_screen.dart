import 'dart:async';

import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

import '../config/viewer_config_notifier.dart';

class ViewerScreen extends HookWidget {
  final List<String> pcdFiles;
  final ViewerConfigNotifier configNotifier;
  final DiTreDiController controller;

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
    final isFrameLoading = useState(true);
    final playbackTimer = useRef<Timer?>(null);

    useEffect(() {
      playbackTimer.value?.cancel();
      if (!isPlaying.value || pcdFiles.length <= 1 || isFrameLoading.value) {
        return null;
      }

      playbackTimer.value = Timer(
        const Duration(milliseconds: 33),
        () {
          isFrameLoading.value = true;
          currentIndex.value = (currentIndex.value + 1) % pcdFiles.length;
        },
      );

      return () => playbackTimer.value?.cancel();
    }, [isPlaying.value, isFrameLoading.value, currentIndex.value, pcdFiles.length]);

    return PopScope<DiTreDiController>(
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
                  isFrameLoading.value = false;
                },
                onError: (_) {
                  isFrameLoading.value = false;
                },
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: _PointSizeControl(configNotifier: configNotifier),
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
                  onPressed: () => configNotifier.updatePointSize(size + 0.5),
                ),
                Text(size.toStringAsFixed(1)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => configNotifier.updatePointSize(size - 0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
