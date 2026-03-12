import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
