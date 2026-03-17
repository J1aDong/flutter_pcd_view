# Flutter PCD View

高性能的 Flutter 点云数据查看器库，使用 Rust FFI 解析点云，并在当前阶段通过 **移动端原生 Texture 渲染** 承载点云显示：Android 使用 OpenGL ES，iOS 使用 Metal。

## 当前状态

- ✅ Rust PCD 解析与点云预处理
- ✅ Android 原生 Texture 渲染链
- ✅ iOS Metal Texture 渲染链
- ✅ `PcdView.fromFile` / `PcdView.fromPoints` 进入移动端 native renderer
- ✅ Flutter 手势驱动 native 相机

## 当前限制

- 当前版本仅支持 **Android / iOS 原生渲染**
- 当前已移除旧的 Flutter/DiTreDi 渲染链，库不再维护双渲染后端
- Android 真机性能与首帧稳定性仍在继续收口

## 安装

```yaml
dependencies:
  flutter_pcd_view: ^0.0.1
```

## 快速开始

```dart
import 'package:flutter/material.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

final controller = NativeCameraController();

PcdView.fromFile(
  filePath: '/path/to/file.pcd',
  controller: controller,
  config: const ViewerConfig(
    pointSize: 1.0,
    backgroundColor: Colors.black,
    showAxes: true,
  ),
)
```

## 原生渲染相关配置

`ViewerConfig.performance` 目前额外支持：

- `nativePointBudget`：移动端 native renderer 绘制点预算（`0` = 不限制）
- `nativeRenderScale`：原生纹理渲染比例，当前可在 example 设置页调节到 `2.0`

示例：

```dart
ViewerConfig(
  performance: const PerformanceConfig(
    nativePointBudget: 150000,
    nativeRenderScale: 2.0,
  ),
)
```

## 示例应用

查看 `example/` 目录获取完整示例。当前 example 已包含：

- Android / iOS Native 渲染状态卡
- 点预算与渲染比例设置项
- 手势旋转/缩放调试入口

## 后续计划

- 继续优化 Android 首帧稳定性、清晰度、点预算和渲染质量
- 补齐 iOS 真机专项验证与渲染细节优化
- 完成更完整的真机性能验证

## 许可证

MIT
