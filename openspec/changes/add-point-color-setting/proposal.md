## Why

当前查看器的点颜色没有独立配置能力，点云在默认场景下统一显示为白色，用户只能调整背景颜色，无法快速根据不同背景或演示需求切换点颜色，影响可读性与调试效率。现在补齐这一能力，可以让查看器的显示配置更完整，也让 example 设置页具备更直接的视觉调节入口。

## What Changes

- 在 `ViewerConfig` 中新增点颜色配置，作为查看器的基础显示参数之一。
- 在点云渲染链中使用该点颜色作为默认点颜色来源，使未携带自定义颜色的点云能够按配置显示。
- 在 example 的查看器设置页中，于“背景颜色”下方新增“点颜色”设置入口。
- 在 `ViewerConfigNotifier` 的持久化读写中补齐点颜色配置的保存与恢复。

## Capabilities

### New Capabilities
- `viewer-point-color-settings`: 为查看器提供点颜色配置、持久化与设置页调节能力。

### Modified Capabilities
- `viewer-performance-settings`: 无

## Impact

- `lib/src/config/viewer_config.dart`
- `lib/src/widgets/pcd_view_widget.dart`
- `example/lib/config/viewer_config_notifier.dart`
- `example/lib/screens/settings_screen.dart`
- Android / iOS native renderer 配置同步逻辑（如需要跟随配置变更更新渲染颜色）
