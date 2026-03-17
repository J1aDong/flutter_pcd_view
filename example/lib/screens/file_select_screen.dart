import 'dart:convert';
import 'dart:io';

import 'package:ditredi/ditredi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../config/viewer_config_notifier.dart';
import 'viewer_screen.dart';

class FileSelectScreen extends HookWidget {
  final ViewerConfigNotifier configNotifier;

  const FileSelectScreen({super.key, required this.configNotifier});

  @override
  Widget build(BuildContext context) {
    final fileList = useState<List<String>>([]);
    final selectedFile = useState<String?>(null);
    final viewerController = useMemoized(
      () => DiTreDiController(
        rotationX: configNotifier.config.camera.rotationX,
        rotationY: configNotifier.config.camera.rotationY,
        userScale: configNotifier.config.camera.zoom,
        minUserScale: configNotifier.config.camera.minZoom,
        maxUserScale: configNotifier.config.camera.maxZoom,
      ),
      const [],
    );

    useEffect(() {
      Future<void>(
        () => _loadBundledPcdAssets(fileList, selectedFile),
      );
      return null;
    }, const []);

    return Column(
      children: [
        _Toolbar(
          onPickFiles: () => _pickFiles(context, fileList, selectedFile),
          onClearFiles: () {
            fileList.value = [];
            selectedFile.value = null;
          },
        ),
        Expanded(
          child: fileList.value.isEmpty
              ? const _EmptyState()
              : _FileList(
                  files: fileList.value,
                  selectedFile: selectedFile.value,
                  onSelect: (path) {
                    // 点击已选中项则取消选择
                    selectedFile.value = selectedFile.value == path ? null : path;
                  },
                ),
        ),
        _PlayButton(
          enabled: selectedFile.value != null,
          onPlay: () => Navigator.push<DiTreDiController>(
            context,
            MaterialPageRoute(
              builder: (_) => ViewerScreen(
                pcdFiles: [selectedFile.value!],
                configNotifier: configNotifier,
                controller: viewerController,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadBundledPcdAssets(
    ValueNotifier<List<String>> fileList,
    ValueNotifier<String?> selectedFile,
  ) async {
    if (fileList.value.isNotEmpty) return;

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifestMap = json.decode(manifestContent) as Map<String, dynamic>;

    final assetKeys = manifestMap.keys
        .where((key) => key.startsWith('assets/'))
        .where((key) => key.toLowerCase().endsWith('.pcd'))
        .toList()
      ..sort();

    if (assetKeys.isEmpty) return;

    final baseDir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}flutter_pcd_view_assets',
    );
    if (!baseDir.existsSync()) {
      await baseDir.create(recursive: true);
    }

    final copiedPaths = <String>[];
    for (final key in assetKeys) {
      final filename = key.split('/').last;
      final outFile = File(
        '${baseDir.path}${Platform.pathSeparator}$filename',
      );

      if (!outFile.existsSync()) {
        final data = await rootBundle.load(key);
        await outFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }

      if (outFile.existsSync()) {
        copiedPaths.add(outFile.path);
      }
    }

    if (copiedPaths.isEmpty) return;

    fileList.value = copiedPaths;
    // 默认选中第一个
    selectedFile.value = copiedPaths.first;
  }

  Future<void> _pickFiles(
    BuildContext context,
    ValueNotifier<List<String>> fileList,
    ValueNotifier<String?> selectedFile,
  ) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pcd'],
        allowMultiple: true,
      );
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '文件过滤器不受支持，已降级为选择全部文件: ${e.message ?? e.code}',
            ),
          ),
        );
      }
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
    }

    if (result == null) return;

    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => File(path).existsSync())
        .where((path) => path.toLowerCase().endsWith('.pcd'))
        .toList();

    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选中任何 .pcd 文件')),
        );
      }
      return;
    }

    final newPaths = {...fileList.value, ...paths}.toList()..sort();
    fileList.value = newPaths;
    // 选中新添加的第一个文件
    selectedFile.value = paths.first;
  }
}

class _Toolbar extends StatelessWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onClearFiles;

  const _Toolbar({required this.onPickFiles, required this.onClearFiles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onPickFiles,
            icon: const Icon(Icons.add),
            label: const Text('添加 PCD 文件'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onClearFiles,
            icon: const Icon(Icons.clear_all),
            label: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('正在加载内置样例或点击"添加 PCD 文件"选择文件', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  final List<String> files;
  final String? selectedFile;
  final void Function(String) onSelect;

  const _FileList({
    required this.files,
    required this.selectedFile,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, i) {
        final path = files[i];
        final name = path.split('/').last;
        final selected = selectedFile == path;
        return ListTile(
          onTap: () => onSelect(path),
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(name),
          subtitle: Text(path, style: const TextStyle(fontSize: 11)),
          trailing: Icon(
            Icons.insert_drive_file_outlined,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPlay;

  const _PlayButton({required this.enabled, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: enabled ? onPlay : null,
          icon: const Icon(Icons.play_circle_outline, size: 28),
          label: const Text('开始查看', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
