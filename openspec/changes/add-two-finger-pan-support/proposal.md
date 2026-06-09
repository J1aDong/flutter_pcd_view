## Why

当前原生点云查看器仅支持单指旋转和双指缩放，不支持双指拖动平移视角。用户在放大后无法通过常见的双指移动手势调整视野位置，导致移动端查看离中心较远的点云区域体验不完整。

## What Changes

- 为原生点云查看器添加双指拖动平移能力，使用多指手势焦点位移驱动视角平移。
- 扩展相机状态，新增平移偏移量，并在 Flutter 控件状态、控制器、桥接层与原生渲染器之间保持同步。
- 更新 Android OpenGL 与 iOS Metal 渲染矩阵，使平移与现有旋转、缩放共同生效。
- 保持单指旋转、双指缩放和滚轮缩放的现有交互语义不变。

## Capabilities

### New Capabilities
- `viewer-camera-pan`: 定义原生点云查看器的双指平移交互，以及平移与缩放、旋转之间的协同行为。

### Modified Capabilities

## Impact

- `lib/src/widgets/pcd_view_widget.dart`
- `lib/src/config/viewer_config.dart`
- `lib/src/native/native_camera_controller.dart`
- `lib/src/native/native_renderer_bridge.dart`
- `android/src/main/kotlin/com/example/flutter_pcd_view/FlutterPcdViewPlugin.kt`
- `ios/Classes/FlutterPcdViewPlugin.swift`
- 原生相机更新通道与公开相机状态模型
