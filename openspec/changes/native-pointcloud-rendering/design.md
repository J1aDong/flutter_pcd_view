## Context

当前项目已经有 Rust 解析链和 Flutter `PcdView` 组件，但主渲染仍然在 `lib/src/widgets/pcd_view_widget.dart` 中通过 `DiTreDi` 完成。现状的问题不是单纯的文件解析速度，而是高点数场景下，Dart 侧对象组装、`Point3DAdapter` 转换、Flutter Canvas 光栅化和手势交互都压在同一条渲染链上，导致旋转、缩放和切换文件时卡顿明显。

这次变更的目标不是再保留一条兼容渲染路径，而是直接把 `PcdView` 的主渲染升级为 native-only：

- Flutter 负责 UI、手势和 `Texture()` 展示；
- Rust 负责点云场景、点缓冲、相机状态和渲染核心；
- Android / iOS 原生层只保留 texture 生命周期和图形上下文桥接。

约束条件：
- 当前实现阶段优先支持 Android，iOS Metal 在 Android 渲染链跑通后补上；
- 必须保留 `PcdView` 对外 widget 形态，不把调用方改成纯原生页面；
- 必须兼容 `fromFile` 和 `fromPoints` 两种入口；
- 不再保留 `DiTreDi` 作为长期 fallback；
- 高点数场景优先保证交互流畅和 GPU 侧绘制效率。

## Goals / Non-Goals

**Goals:**
- 让 `PcdView` 在 Android 上先走原生 texture 渲染路径，并为后续 iOS Metal 补齐保留结构
- 让高点数点云的旋转、缩放、重绘不再依赖 Flutter Canvas 主渲染链
- 复用现有 Rust 解析能力，避免再次引入 C++ 主栈
- 支持 `fromFile` 和 `fromPoints` 两种输入方式进入 native renderer
- 在 Flutter 层保留现有 UI 交互方式，包括手势、状态栏和配置面板
- 为后续点预算、LOD、裁剪和 shader 优化留出可扩展空间

**Non-Goals:**
- 不保留 Flutter/DiTreDi 渲染后端作为长期 fallback
- 不在本次设计中引入 Web 平台支持
- 不在本次设计中实现点选、标注、编辑等高级交互
- 不在首期同时支持 Android Vulkan 与 iOS Metal 的统一抽象层；首期优先 Android OpenGL ES + iOS Metal

## Decisions

### 1. `PcdView` 统一切换为 native-only 渲染路径

**决定：** `PcdView` 不再维护 Flutter/DiTreDi 与 native 双渲染并存结构，而是统一输出 `Texture()`，点云绘制由 native renderer 完成。

**理由：**
- 高性能目标下，双渲染链会带来维护和调优分裂；
- 如果长期保留 `DiTreDi`，后续功能和性能优化都要双份适配；
- 纯 native 路线更符合“移动端高性能 3D 查看器”的最终形态。

**备选方案：**
- 保留 `flutter/native/auto` 三模式：迁移更平滑，但长期维护成本高；
- 只在大点云时切 native：实现复杂且会带来两套行为差异。

### 2. 使用“Rust 渲染核心 + 原生 texture 桥接”的架构

**决定：** Rust 负责场景管理、点缓冲组织、相机更新和渲染核心；Android / iOS 原生层负责 texture 注册、surface 生命周期和图形上下文桥接。

**理由：**
- 项目已有 Rust 解析能力，可直接复用点云读取与预处理逻辑；
- 避免再引入一套独立 C++ 主栈；
- 让大点云数据尽量停留在 Rust/native/GPU 侧，减少 Dart 侧大对象参与。

**备选方案：**
- Flutter 只把点数据传给原生，原生用 Java/Swift/ObjC 负责主渲染：会复制核心逻辑；
- Rust 每帧渲染 RGBA 位图再上传 Texture：CPU 与内存带宽成本太高，不适合高帧率交互。

### 3. Flutter 继续负责手势，native renderer 负责相机执行

**决定：** 手势仍由 Flutter 层处理，Flutter 将标准化后的相机变化（旋转、缩放、平移）发送给 Rust/native renderer；native renderer 根据相机状态重绘。

**理由：**
- 保留当前 Flutter 页面结构和交互方式，避免把整个交互栈下沉到原生；
- Flutter 更容易与现有设置页、状态栏、播放控制联动；
- 原生侧只处理渲染，不与 UI 控件耦合。

**备选方案：**
- 原生侧自己处理手势：平台差异更大，Flutter overlay 控件更难协同。

### 4. `fromFile` 与 `fromPoints` 都必须接入 native renderer

**决定：** `fromFile` 直接走 Rust 解析 + native renderer；`fromPoints` 通过紧凑内存布局上传到 native renderer，而不是继续保留 Flutter 渲染特例。

**理由：**
- 用户已明确要求仅保留 native 路线；
- 如果 `fromPoints` 仍保留 Flutter 渲染，就意味着渲染架构没有真正统一；
- 统一入口后，后续点预算、LOD、裁剪都能复用同一套管线。

**备选方案：**
- 首期仅 `fromFile` 走 native，`fromPoints` 继续 Flutter：短期实现快，但不符合 native-only 目标。

### 5. 平台图形后端当前阶段采用 Android OpenGL ES，iOS Metal 后补

**决定：**
- 当前实现阶段只落 Android OpenGL ES 渲染链；
- iOS Metal 先保留设计方向和接口预留，待 Android 跑通后补上；
- 后续是否扩展 Vulkan 再单独评估。

**理由：**
- 用户明确要求先把 Android native 渲染链跑通，再补 iOS；
- 现有仓库尚无 Android / iOS 插件层与 texture 桥接基础设施，同时双端并行会显著放大实现面；
- 对当前阶段来说，先把 Android texture 管线和高点数渲染跑通，更有利于验证整体路线。

**备选方案：**
- Android + iOS 同步推进：目标完整，但当前阶段实现面过大；
- Android Vulkan：上限更高，但首期复杂度明显增加；
- 统一跨平台图形抽象（如额外渲染框架）：可行，但会放大接入成本和调试面。

## Risks / Trade-offs

- **移除 Flutter 渲染 fallback 后，native 初始化失败会直接影响可用性** → 通过更明确的错误上报、初始化自检和示例工程真机验证降低风险
- **Android / iOS 各自维护一层图形桥接代码，调试成本上升** → 保持桥接层尽量薄，把场景、点缓冲和渲染控制收敛到 Rust 核心
- **`fromPoints` 接入 native 需要设计高效的紧凑缓冲协议** → 统一使用 packed buffer / typed data 布局，避免对象级拷贝
- **首期只做 OpenGL ES + Metal，后续想扩 Vulkan 需要额外抽象** → 首先确保现有平台可用，再评估是否值得引入更重的抽象
- **示例应用和配置逻辑需要跟着 native renderer 对齐** → 把配置同步、相机更新、错误提示纳入首批验证任务

## Migration Plan

1. 在 `PcdView` 内新增 native texture 渲染 widget 和渲染控制接口；
2. 接入 Android / iOS 原生 texture 注册与渲染桥接；
3. 让 `fromFile` 先走 Rust + native renderer，验证大点云流畅度；
4. 让 `fromPoints` 也切换到 packed buffer 上传方案；
5. 删除 `DiTreDi`、`Point3DAdapter` 和 Flutter figures 组装路径；
6. 更新 example 与配置界面，改为验证 native 渲染功能；
7. 完成 Android / iOS 真机验证后，将 native-only 路线作为唯一实现。

如果需要回滚，本次变更只能通过恢复旧版本代码实现，因为设计上不再保留运行时 fallback。

## Open Questions

1. Rust 渲染核心是否直接持有平台图形资源句柄，还是由平台桥接层持有句柄再调用 Rust 渲染命令更稳妥？
2. `fromPoints` 的紧凑缓冲协议使用哪种布局最适合当前 `Point3D` 数据模型？
3. native renderer 首期是否就要支持网格、坐标轴、连线段与点云同屏绘制，还是允许分批补齐？
4. Android 图形后端是否需要从一开始就为 Vulkan 预留抽象接口，还是首期只聚焦 OpenGL ES？
