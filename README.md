# Flutter PCD View

高性能的 Flutter 点云数据查看器库，使用 Rust FFI 解析点云，并在当前阶段优先通过 **Android 原生 Texture + OpenGL ES** 完成渲染。

## 当前状态

- ✅ Rust PCD 解析与点云预处理
- ✅ Android 原生 Texture 渲染链
- ✅ `PcdView.fromFile` / `PcdView.fromPoints` 进入 Android native renderer
- ✅ Flutter 手势驱动 native 相机
- 🚧 iOS Metal 渲染后端待补

## 当前限制

- 当前版本 **仅正式支持 Android 原生渲染**
- iOS 侧暂未接入 Metal 渲染后端，调用 `PcdView` 时会提示当前平台暂不支持
- 当前已移除旧的 Flutter/DiTreDi 渲染链，库不再维护双渲染后端

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

- `nativePointBudget`：Android native renderer 绘制点预算（`0` = 不限制）
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

- Android Native 渲染状态卡
- 点预算与渲染比例设置项
- 手势旋转/缩放调试入口

## 后续计划

- 补齐 iOS Metal 渲染后端
- 继续优化 Android 侧清晰度、点预算和渲染质量
- 完成更完整的真机性能验证

## 许可证

MIT
