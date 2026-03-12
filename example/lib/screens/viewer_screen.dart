import 'dart:async';
import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_pcd_view/pcd_view.dart';
import '../config/viewer_config_notifier.dart';

class ViewerScreen extends HookWidget {
  final List<String> pcdFiles;
  final ViewerConfigNotifier configNotifier;

  const ViewerScreen({
    super.key,
    required this.pcdFiles,
    required this.configNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = useState(0);
    final isPlaying = useState(pcdFiles.length > 1);
    final controller = useMemoized(() => DiTreDiController());

    useEffect(() {
      if (!isPlaying.value || pcdFiles.length <= 1) return null;

      final timer = Timer.periodic(
        const Duration(milliseconds: 33), // ~30 FPS
        (_) {
          currentIndex.value = (currentIndex.value + 1) % pcdFiles.length;
        },
      );

      return timer.cancel;
    }, [isPlaying.value]);

    return Scaffold(
      appBar: AppBar(
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
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: _PointSizeControl(configNotifier: configNotifier),
          ),
        ],
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
