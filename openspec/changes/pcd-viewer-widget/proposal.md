## Why

当前 Flutter 生态缺少高性能的 PCD（点云数据）查看器组件。现有的 PointCloudDataViewer 是一个完整应用，但没有封装为可复用的 widget。我们需要将其核心功能提取为独立的 `pcd_view` 库，底层使用 Rust 提升解析性能，支持 Android 和 iOS 平台。

## What Changes

- 创建 `flutter_pcd_view` 库，提供 `PcdView` widget 用于显示点云数据
- 使用 Rust FFI 实现高性能 PCD 文件解析（替代现有 Dart 实现）
- 支持 ASCII 和 Binary 格式的 PCD 文件
- 支持 XYZ、XYZRGB、XYZHSV 三种点云字段格式
- 提供交互式 3D 查看器（旋转、缩放、平移）
- 提供点大小、网格、坐标轴等可配置选项
- 在 `example/` 目录提供完整的 demo 应用（参考 PointCloudDataViewer）
- 跨平台支持：Android、iOS

## Capabilities

### New Capabilities

- `pcd-parsing`: PCD 文件解析能力（Rust 实现，支持 ASCII/Binary 格式，XYZ/XYZRGB/XYZHSV 字段）
- `pcd-widget`: PcdView widget 封装（基于 DiTreDi 3D 渲染，支持手势交互）
- `viewer-config`: 查看器配置能力（点大小、网格范围、背景色、坐标轴显示）
- `demo-app`: 示例应用（文件选择、查看器设置、多文件播放）

### Modified Capabilities

<!-- 无现有能力需要修改 -->

## Impact

- 新增 `lib/` 目录：核心库代码
  - `lib/pcd_view.dart`：主 widget 导出
  - `lib/src/parser/`：Rust FFI 绑定
  - `lib/src/widgets/`：PcdView widget 实现
  - `lib/src/models/`：数据模型（Point3D、PcdData 等）
  - `lib/src/config/`：配置类（ViewerConfig）
- 新增 `rust/` 目录：Rust 解析器
  - `rust/src/lib.rs`：PCD 解析核心逻辑
  - `rust/Cargo.toml`：Rust 依赖配置
- 修改 `example/` 目录：demo 应用（参考 PointCloudDataViewer）
  - `example/lib/main.dart`：入口
  - `example/lib/screens/`：文件选择、查看器设置页面
- 新增依赖：
  - `ditredi`：3D 渲染引擎
  - `vector_math`：向量数学库
  - `flutter_rust_bridge`：Rust FFI 桥接
  - `file_picker`：文件选择（demo 用）
- 构建配置：
  - Android NDK 配置（支持 Rust 编译）
  - iOS 配置（支持 Rust 静态库链接）
