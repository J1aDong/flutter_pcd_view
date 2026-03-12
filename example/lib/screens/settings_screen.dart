import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_pcd_view/pcd_view.dart';
import '../config/viewer_config_notifier.dart';

class SettingsScreen extends HookWidget {
  final ViewerConfigNotifier configNotifier;

  const SettingsScreen({super.key, required this.configNotifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: configNotifier,
      builder: (context, _) {
        final config = configNotifier.config;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('性能优化'),
            _DeduplicationSwitch(
              value: config.performance.enableDeduplication,
              onChanged: configNotifier.updateEnableDeduplication,
            ),
            if (config.performance.enableDeduplication)
              _DedupPrecisionSlider(
                value: config.performance.dedupPrecision,
                onChanged: configNotifier.updateDedupPrecision,
              ),
            _VoxelSizeSlider(
              value: config.performance.voxelSize,
              onChanged: configNotifier.updateVoxelSize,
            ),
            _MaxPointsInput(
              value: config.performance.maxPoints,
              onChanged: configNotifier.updateMaxPoints,
            ),
            if (config.performance.isEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: configNotifier.resetPerformance,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置优化设置'),
                ),
              ),
            const Divider(height: 32),
            _SectionTitle('离群点去除'),
            _SORSwitch(
              value: config.processing.sor != null,
              onChanged: configNotifier.updateSOREnabled,
            ),
            if (config.processing.sor != null) ...[
              _SORKSlider(
                value: config.processing.sor!.k,
                onChanged: configNotifier.updateSORK,
              ),
              _SORStdRatioSlider(
                value: config.processing.sor!.stdRatio,
                onChanged: configNotifier.updateSORStdRatio,
              ),
            ],
            _RORSwitch(
              value: config.processing.ror != null,
              onChanged: configNotifier.updateROREnabled,
            ),
            if (config.processing.ror != null) ...[
              _RORRadiusSlider(
                value: config.processing.ror!.radius,
                onChanged: configNotifier.updateRORRadius,
              ),
              _RORMinNeighborsSlider(
                value: config.processing.ror!.minNeighbors,
                onChanged: configNotifier.updateRORMinNeighbors,
              ),
            ],
            if (config.processing.isEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: configNotifier.resetProcessing,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置处理设置'),
                ),
              ),
            const Divider(height: 32),
            _SectionTitle('连线模式'),
            _ConnectEnabledSwitch(
              value: config.processing.connect?.isEnabled ?? false,
              onChanged: configNotifier.updateConnectEnabled,
            ),
            if (config.processing.connect?.isEnabled ?? false) ...[
              _ConnectModeSelector(
                value: config.processing.connect!.mode,
                onChanged: configNotifier.updateConnectMode,
              ),
              _ConnectMaxDistanceSlider(
                value: config.processing.connect!.maxDistance,
                onChanged: configNotifier.updateConnectMaxDistance,
              ),
            ],
            const Divider(height: 32),
            _SectionTitle('点云设置'),
            _PointSizeSlider(
              value: config.pointSize,
              onChanged: configNotifier.updatePointSize,
            ),
            const Divider(height: 32),
            _SectionTitle('网格设置'),
            _GridVisibleSwitch(
              value: config.grid.visible,
              onChanged: configNotifier.updateGridVisible,
            ),
            _GridRangeSlider(
              value: config.grid.range,
              onChanged: configNotifier.updateGridRange,
            ),
            const Divider(height: 32),
            _SectionTitle('显示设置'),
            _ShowAxesSwitch(
              value: config.showAxes,
              onChanged: configNotifier.updateShowAxes,
            ),
            _BackgroundColorPicker(
              color: config.backgroundColor,
              onChanged: configNotifier.updateBackgroundColor,
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DeduplicationSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DeduplicationSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('去重优化'),
      subtitle: const Text('使用空间哈希去除重复点'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DedupPrecisionSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DedupPrecisionSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('去重精度'),
            Text('${value.toStringAsFixed(4)} m'),
          ],
        ),
        Slider(
          value: value,
          min: 0.0001,
          max: 0.1,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _VoxelSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _VoxelSizeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('体素大小'),
            Text(value > 0 ? '${value.toStringAsFixed(2)} m' : '禁用'),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          onChanged: onChanged,
        ),
        const Text(
          '体素下采样：保留空间结构的同时减少点数',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _MaxPointsInput extends HookWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _MaxPointsInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value > 0 ? value.toString() : '');

    return ListTile(
      title: const Text('最大点数'),
      subtitle: const Text('超过此数量将均匀采样（0 = 无限制）'),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '无限制',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onSubmitted: (text) {
            final parsed = int.tryParse(text);
            onChanged(parsed ?? 0);
          },
        ),
      ),
    );
  }
}

class _PointSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PointSizeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('点大小'),
            Text('${value.toStringAsFixed(1)} px'),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 10.0,
          divisions: 18,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _GridVisibleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GridVisibleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('显示网格'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _GridRangeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _GridRangeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('网格范围'),
            Text('${value.toStringAsFixed(0)} m'),
          ],
        ),
        Slider(
          value: value,
          min: 5.0,
          max: 50.0,
          divisions: 9,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ShowAxesSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ShowAxesSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('显示坐标轴'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _BackgroundColorPicker extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _BackgroundColorPicker({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('背景颜色'),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onTap: () => _showColorPicker(context),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('选择背景颜色'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.black,
            Colors.white,
            Colors.grey[800]!,
            Colors.blue[900]!,
            Colors.indigo[900]!,
          ].map((c) => _ColorOption(color: c, onTap: () {
            onChanged(c);
            Navigator.pop(context);
          })).toList(),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorOption({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// SOR Settings
class _SORSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SORSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('统计离群点去除 (SOR)'),
      subtitle: const Text('基于统计的离群点过滤'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SORKSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SORKSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('近邻数量 (K)'),
            Text('$value'),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _SORStdRatioSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SORStdRatioSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('标准差倍数'),
            Text(value.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: value,
          min: 0.5,
          max: 3.0,
          divisions: 25,
          onChanged: onChanged,
        ),
        const Text(
          '值越小，过滤越严格',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// ROR Settings
class _RORSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RORSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('半径离群点去除 (ROR)'),
      subtitle: const Text('基于半径的离群点过滤'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _RORRadiusSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _RORRadiusSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('搜索半径'),
            Text('${value.toStringAsFixed(2)} m'),
          ],
        ),
        Slider(
          value: value,
          min: 0.01,
          max: 1.0,
          divisions: 99,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RORMinNeighborsSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RORMinNeighborsSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最小邻居数'),
            Text('$value'),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          onChanged: (v) => onChanged(v.round()),
        ),
        const Text(
          '半径内邻居数少于此值的点将被移除',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// Connect Settings
class _ConnectEnabledSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConnectEnabledSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('启用连线模式'),
      subtitle: const Text('将相邻点连接成线'),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ConnectModeSelector extends StatelessWidget {
  final ConnectMode value;
  final ValueChanged<ConnectMode> onChanged;

  const _ConnectModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('连线模式'),
      trailing: DropdownButton<ConnectMode>(
        value: value,
        items: const [
          DropdownMenuItem(
            value: ConnectMode.sequential,
            child: Text('顺序连接'),
          ),
          DropdownMenuItem(
            value: ConnectMode.nearestNeighbor,
            child: Text('近邻连接'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _ConnectMaxDistanceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ConnectMaxDistanceSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最大连接距离'),
            Text('${value.toStringAsFixed(2)} m'),
          ],
        ),
        Slider(
          value: value,
          min: 0.1,
          max: 2.0,
          divisions: 19,
          onChanged: onChanged,
        ),
        const Text(
          '近邻模式：仅连接距离在此范围内的点',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
