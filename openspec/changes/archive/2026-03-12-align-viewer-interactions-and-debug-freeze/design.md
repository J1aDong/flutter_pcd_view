## Context

当前卡死问题不是单一渲染慢，而是查看器链路里有两段重工作都落在了用户可感知路径上：

1. `lib/src/widgets/pcd_view_widget.dart` 在文件加载时直接走同步解析调用，当前 Rust API 通过 `rust/src/api.rs` 上的 `#[flutter_rust_bridge::frb(sync)]` 暴露为同步 FFI，导致大文件解析会占住 UI 所在路径。
2. `lib/src/models/point_3d_adapter.dart` 在点大小变化时会整批重建 DiTreDi `Point3D` 列表，因此即使不重新解析文件，显示层更新仍可能在大点云上造成明显卡顿。

同时，现有 demo 查看器交互没有完全对齐参考实现 `/Users/mr.j/myRoom/code/flutter/PointCloudDataViewer_flutter-main/lib/screen/viewer_screen.dart` 中的 `GestureDetector + Listener(onPointerSignal)` 模式；参考项目已经验证了拖拽旋转、捏合缩放、滚轮缩放和返回时保留控制器状态的交互方式。

这次 change 需要同时处理三件事：
- 把解析与渲染准备从阻塞式路径中挪开
- 让查看器交互与参考项目对齐
- 给关键阶段补上可定位问题的日志

## Goals / Non-Goals

**Goals:**
- 打开大体积 PCD 文件时，界面保持可响应，至少能显示明确加载态并及时处理返回/切屏。
- 让查看器具备参考项目同等级的旋转、捏合缩放、滚轮缩放交互。
- 将“文件解析”“点数据转渲染对象”“导航取消/丢弃陈旧结果”纳入统一请求生命周期。
- 让 display-only 配置更新与 file-data 工作解耦，避免设置变更触发完整重解析。
- 为大文件卡死定位提供结构化日志和耗时信息。

**Non-Goals:**
- 不重写底层 3D 渲染引擎。
- 不新增点云编辑、滤波、下采样等算法功能。
- 不扩展到网络流式点云或 Web 平台。
- 不追求一次性解决所有超大点云的性能极限问题；本次重点是避免当前 demo 的明显假死和交互缺失。

## Decisions

### Decision 1: 将 viewer 的请求生命周期从 widget build 路径中拆开

查看器需要一个独立的请求状态机，而不是在 build/useEffect 路径里直接做重工作。设计上会把一次“打开文件”的过程视为一个带 request id 的会话：`idle -> loading -> preparing -> ready/error`。

**Why:**
- 大文件打开、快速返回、连续切换文件、本地多文件播放都需要区分“当前请求”和“过期请求”。
- 没有请求生命周期时，dispose 后的异步/重工作结果很容易回写到已离开的页面，或让返回显得很慢。

**Alternatives considered:**
- 继续在 widget 生命周期里直接触发加载：实现简单，但无法优雅处理陈旧结果和取消。
- 只增加 loading spinner：用户可见反馈会改善，但主线程阻塞根因仍在。

### Decision 2: 将当前同步 FRB 解析入口改为非阻塞的解析调用

本次不会继续把 `#[frb(sync)]` 暴露的同步解析接口放在 viewer 打开路径上，而是把解析调用改成非阻塞模式，让 Dart 侧以 `Future` 方式等待结果，并把解析完成后的状态切换纳入请求生命周期。

**Why:**
- 当前最明显的卡死根因来自同步 FFI 解析路径，而不是单纯的相机控制缺失。
- 只有先把解析从同步调用改成非阻塞，loading 态、取消、日志耗时这些能力才有意义。

**Alternatives considered:**
- 保持同步解析，外围包一层异步函数：表面 API 变成 `Future`，但底层仍同步阻塞，无法解决卡死。
- 在 Dart 侧额外套 isolate 而不调整 FFI 暴露方式：实现复杂度更高，且调试边界更分散。

### Decision 3: 将“解析结果”和“渲染对象”分层缓存

查看器内部将保留解析后的原始点数据作为独立层，再按显示配置生成当前渲染对象；文件解析与显示配置更新分离处理。

**Why:**
- 当前点大小变化会整批重建 DiTreDi 点对象，说明 display-only 变化和 file-data 变化被混在一起了。
- 分层后，点大小、网格、坐标轴、背景色等更新至少不再触发重解析，并能进一步压缩重建范围。

**Alternatives considered:**
- 每次配置变化都从文件重新加载：最容易实现，但大文件体验不可接受。
- 直接重写自定义点云 renderer：潜在收益更大，但超出本次修复范围。

### Decision 4: 交互层按参考项目对齐，显式接管 drag/pinch/scroll

查看器交互会参考对标项目的模式，由屏幕/组件显式处理拖拽旋转、捏合缩放和滚轮缩放，并保持与当前屏幕级控制区共存。

**Why:**
- 参考项目已经证明这套交互在当前场景下有效。
- 直接依赖默认渲染组件行为不利于保证移动端和桌面端输入行为一致。

**Alternatives considered:**
- 继续依赖当前 `DiTreDi` 默认行为：行为不透明，也无法确保与参考项目一致。
- 额外引入新的 3D 交互库：不必要地扩大改动面。

### Decision 5: 用结构化日志覆盖 parse / prepare / navigation 三段关键路径

为每次 viewer 请求生成统一 request id，在解析开始/结束、场景准备开始/结束、页面返回取消、陈旧结果丢弃等节点输出统一 tag 的 debug 日志。

**Why:**
- 当前问题需要先定位“卡在解析”还是“卡在点对象重建/scene prepare”，日志必须能把两个阶段区分开。
- request id 可以让同一时间的多次打开/返回/切换在日志里可追踪。

**Alternatives considered:**
- 只打零散 print：很快会在多次切换文件时失去可读性。
- 记录完整点云内容：日志量过大，也不利于排查。

## Risks / Trade-offs

- **[风险] 非阻塞加载会引入更多状态分支** → **Mitigation:** 明确限定为 `idle/loading/preparing/ready/error` 五态，并统一通过 request id 丢弃陈旧结果。
- **[风险] 即使不重解析，超大点云在显示层重建时仍可能有卡顿** → **Mitigation:** 先确保 display-only 更新不重解析；若点大小变更仍重，可在实现阶段增加局部重建或节流。
- **[风险] 交互对齐后可能与现有 overlay 控件命中区域冲突** → **Mitigation:** 明确手势层仅接管画布区域，控制按钮保持独立命中。
- **[风险] 增加日志后输出变多** → **Mitigation:** 统一 tag，默认只输出摘要、计时和元信息，不输出原始点数组。

## Migration Plan

1. 调整 Rust / FRB 暴露方式，使文件解析从同步调用改为可等待的非阻塞调用。
2. 重构 `PcdView` 的加载路径，引入 request id、状态机和陈旧结果丢弃策略。
3. 分离“解析后点数据”和“渲染对象”状态，确保配置变更不触发重新解析。
4. 在 viewer 组件或 demo screen 中补齐 drag / pinch / scroll 交互层。
5. 加入结构化日志并用 `pointcloud_map.pcd` 做 Android 真机验证。
6. 如果新链路引入明显回归，可回退到旧渲染表现，但保留日志和请求生命周期框架作为最小诊断基线。

## Open Questions

- 点大小变化如果仍需要整批重建渲染对象，是否需要在实现阶段为该操作增加节流或延迟提交？
- 是否需要把 loading 态再细分为“解析中 / 场景准备中”，便于用户理解当前等待阶段？
- 是否要在 demo 中额外暴露一个开发开关，用于启用更详细的 viewer 诊断日志？
