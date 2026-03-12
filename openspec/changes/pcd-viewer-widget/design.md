## Context

当前项目是一个 Flutter package，需要将 PointCloudDataViewer 的核心功能封装为可复用的 `PcdView` widget。现有实现使用纯 Dart 解析 PCD 文件，性能在大文件（100K+ 点）时较差。我们需要：

1. 使用 Rust 实现高性能解析器
2. 通过 FFI 桥接 Rust 和 Flutter
3. 支持 Android 和 iOS 平台的 Rust 编译
4. 保持 API 简洁易用
5. 提供完整的 demo 应用用于测试和展示

约束条件：
- 必须支持 Android (arm64-v8a, armeabi-v7a) 和 iOS (arm64, x86_64 simulator)
- 库代码位于 `lib/`，demo 位于 `example/`
- 使用 DiTreDi 作为 3D 渲染引擎（已在参考项目中验证）
- 遵循 Flutter package 最佳实践

## Goals / Non-Goals

**Goals:**
- 提供高性能的 PCD 文件解析（Rust 实现）
- 封装易用的 `PcdView` widget
- 支持 ASCII 和 Binary PCD 格式
- 支持 XYZ、XYZRGB、XYZHSV 字段类型
- 提供手势交互（旋转、缩放）
- 提供可配置的查看器选项（点大小、网格、坐标轴等）
- 跨平台支持（Android、iOS）
- 提供完整的 demo 应用

**Non-Goals:**
- 不支持 PCD 文件编辑或导出
- 不支持实时网络流式传输（UDP）
- 不支持点云滤波或处理算法
- 不支持 Web 平台（Rust FFI 在 Web 上复杂度高）
- 不实现自定义 3D 渲染引擎（使用 DiTreDi）

## Decisions

### Decision 1: 使用 Rust + flutter_rust_bridge 实现解析器

**Rationale:**
- Rust 提供接近 C++ 的性能，内存安全
- `flutter_rust_bridge` 提供成熟的 FFI 绑定方案，自动生成桥接代码
- 支持 Android NDK 和 iOS 静态库编译
- 相比纯 Dart 实现，大文件解析速度提升 5-10 倍

**Alternatives considered:**
- 纯 Dart 实现：性能不足，大文件卡顿
- C++ + dart:ffi：需要手动管理内存，开发效率低
- 使用现有 C++ PCD 库（PCL）：体积过大（100MB+），移动端不适用

### Decision 2: 使用 DiTreDi 作为 3D 渲染引擎

**Rationale:**
- 参考项目已验证可行性
- 纯 Dart 实现，无需额外 native 依赖
- 支持自定义 painter，可扩展性强
- 提供手势控制和相机管理

**Alternatives considered:**
- flutter_cube：功能较弱，不支持大规模点云
- 自定义 Canvas 绘制：开发成本高，性能不如 DiTreDi

### Decision 3: 库结构采用标准 Flutter package 布局

**Structure:**
```
lib/
  pcd_view.dart                 # 主导出文件
  src/
    parser/
      pcd_parser.dart           # Dart 侧 FFI 接口
      ffi_bridge.dart           # flutter_rust_bridge 生成的绑定
    widgets/
      pcd_view_widget.dart      # PcdView widget 实现
    models/
      point_3d.dart             # 点云数据模型
      pcd_data.dart             # PCD 文件元数据
    config/
      viewer_config.dart        # 查看器配置类
rust/
  src/
    lib.rs                      # Rust 解析器入口
    parser.rs                   # PCD 解析逻辑
  Cargo.toml
example/
  lib/
    main.dart
    screens/
      file_select_screen.dart
      viewer_screen.dart
      settings_screen.dart
```

**Rationale:**
- 清晰的模块划分，易于维护
- `src/` 目录隐藏内部实现细节
- Rust 代码独立于 Flutter 代码，便于单独测试

### Decision 4: Demo 应用复用 PointCloudDataViewer 的 UI 结构

**Rationale:**
- 已验证的 UX 流程
- 包含文件选择、查看器设置、多文件播放等完整功能
- 减少设计和开发时间

**Components to replicate:**
- Tab 导航（文件选择 / 查看器设置）
- 侧边栏控制（点大小调整）
- 多文件播放器（Timer-based 序列播放）

### Decision 5: Rust 解析器返回扁平化数据结构

**Interface:**
```rust
pub struct Point3D {
    pub x: f64,
    pub y: f64,
    pub z: f64,
    pub color: u32,  // ARGB format: 0xAARRGGBB
}

pub fn parse_pcd_file(path: String) -> Result<Vec<Point3D>, String>
```

**Rationale:**
- 简单的数据结构，FFI 传输高效
- 颜色统一为 ARGB u32，避免复杂类型转换
- 错误使用 String 返回，便于 Dart 侧处理

**Alternatives considered:**
- 返回结构化 PcdData（包含 header）：增加 FFI 复杂度，实际用途有限
- 使用 JSON 序列化传输：性能损失大

## Risks / Trade-offs

### Risk 1: Rust 编译环境配置复杂
**Mitigation:**
- 提供详细的 README 配置指南
- 使用 `flutter_rust_bridge_codegen` 自动化生成绑定
- 在 CI/CD 中预编译 Rust 库（未来优化）

### Risk 2: 大文件内存占用
**Trade-off:**
- 100 万点 × 16 bytes ≈ 16MB 内存
- 移动设备可接受，但超大文件（1000 万点+）可能 OOM
**Mitigation:**
- 文档中说明推荐文件大小上限
- 未来可实现分块加载（LOD）

### Risk 3: iOS 静态库体积
**Trade-off:**
- Rust 静态库约 2-5MB（release 模式）
- 增加 app 体积，但性能提升值得
**Mitigation:**
- 使用 `strip` 和 `lto` 优化编译选项
- 文档中说明体积影响

### Risk 4: DiTreDi 性能瓶颈
**Trade-off:**
- DiTreDi 使用 Canvas 绘制，10 万点以上可能掉帧
- 参考项目已验证可用，但不适合超大规模点云
**Mitigation:**
- 文档中说明性能特性
- 未来可考虑 OpenGL/Metal 渲染（大重构）

## Migration Plan

N/A（新项目，无需迁移）

## Open Questions

1. **是否需要支持点云下采样？**
   - 当前设计不包含，但可作为未来优化
   - 可在 Rust 侧实现 voxel grid 下采样

2. **是否需要支持自定义着色器？**
   - DiTreDi 支持自定义 painter，但需要深入研究
   - 暂不实现，保持 API 简洁

3. **是否需要支持点云动画（插值）？**
   - 当前只支持序列播放，不支持帧间插值
   - 可作为未来功能
