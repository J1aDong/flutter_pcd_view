## Why

当前 `PcdView` 在 `lib/src/widgets/pcd_view_widget.dart` 中基于 `DiTreDi` + Flutter 渲染树绘制点云，点数一高时会同时触发 Dart 侧模型转换、Flutter UI 线程布局/手势处理、Canvas 光栅化等开销，导致旋转、缩放和切换文件时出现明显卡顿。项目已经具备 Rust 解析能力，因此这次改动要把点云主渲染链彻底切换到“Rust 渲染核心 + 原生 texture 桥接 + Flutter Texture”，让 Flutter 只负责 UI 和交互，不再承担高点数点云的主绘制。

## What Changes

- 新增移动端原生点云渲染能力：在 Android / iOS 上提供基于原生 texture 的点云显示路径，用于承载高点数场景。
- `PcdView` 统一切换为 native-only 渲染方案，不再保留 Flutter/DiTreDi 主渲染后端。
- 原生后端采用“Rust 渲染核心 + Android/iOS 原生 texture 桥接”的架构，避免每帧把 CPU 位图或大量点对象回传给 Flutter。
- `PcdView.fromFile` 和 `PcdView.fromPoints` 都接入原生渲染路径，其中 `fromPoints` 通过紧凑缓冲上传方式进入 native renderer。
- 移除现有 `DiTreDi` 渲染路径、相关适配层和依赖，示例应用同步改为验证 native 渲染表现。

## Capabilities

### New Capabilities
- `native-pointcloud-rendering`: 面向 Android 和 iOS 的原生点云渲染能力，提供基于 Texture 的高点数渲染、相机交互、配置同步和错误上报。

### Modified Capabilities

## Impact

- **Flutter 端**：
  - `lib/src/widgets/pcd_view_widget.dart`：移除 `DiTreDi` 渲染路径，统一改为 `Texture()` 显示 native renderer 输出
  - `lib/src/config/viewer_config.dart`：补充 native renderer 需要的配置项（如点预算、渲染质量、相机/显示参数）
  - `example/lib/screens/viewer_screen.dart`、`example/lib/screens/settings_screen.dart`：改为验证 native 渲染效果与配置同步
- **Android 原生端**：
  - 新增 texture 注册、surface 生命周期管理、相机控制桥接代码
  - 新增 Android 原生图形后端（首期使用 OpenGL ES）
- **iOS 原生端**：
  - 新增 external texture 注册、Metal 渲染承载与相机控制桥接代码
- **Rust/FFI**：
  - 新增 Rust 渲染核心、场景生命周期、点缓冲上传和相机更新接口
  - 保持现有解析能力可复用，避免重复实现点云读取
- **依赖与结构**：
  - 移除 `ditredi` 及其适配层依赖
  - `pubspec.yaml` 需要补齐 Android / iOS 原生插件注册声明
  - iOS Pod 与 Android Gradle 配置需要支持新增 native renderer 桥接代码
