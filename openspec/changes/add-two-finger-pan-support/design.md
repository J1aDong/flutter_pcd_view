## Context

当前移动端点云查看器的原生纹理渲染入口 `_NativePcdTextureRenderer` 使用 `GestureDetector.onScaleStart/onScaleUpdate` 统一处理触控手势。现有逻辑中，单指拖动映射为 `rotationX/rotationY`，双指手势仅更新 `zoom`，因此用户放大后无法通过双指拖动平移视野。

相机状态当前只包含 `rotationX`、`rotationY`、`zoom`，并分散在 `CameraConfig`、`NativeCameraController`、`PcdView` 内部状态、`NativeRendererBridge` 以及 Android/iOS 原生渲染器中。原生矩阵也只包含沿 z 轴的视图平移和模型旋转，没有横向/纵向平移量。

这个改动会同时触及 Flutter 状态层、MethodChannel 桥接层，以及 Android OpenGL / iOS Metal 的相机矩阵实现，因此需要先约定统一的相机扩展方式。

## Goals / Non-Goals

**Goals:**
- 为原生点云查看器增加双指拖动平移能力。
- 让平移成为统一相机状态的一部分，并在 Flutter 与原生渲染器之间同步。
- 保持单指旋转、双指缩放和滚轮缩放的现有语义。
- 确保场景重载、视口更新后不会丢失当前平移状态。

**Non-Goals:**
- 不引入惯性滚动、回弹、重置手势等额外交互。
- 不为 Web 或非原生渲染路径补齐同等能力。
- 不在这次改动里增加复杂的平移边界约束或可配置手势灵敏度。

## Decisions

### 1. 将平移扩展为统一的相机状态
新增 `panX` / `panY` 两个相机字段，并贯穿 `CameraConfig`、`NativeCameraController`、`PcdView` 内部状态、`NativeRendererBridge.updateCamera` 以及 Android/iOS 原生渲染器。

这样可以保证：
- 双指手势更新后的平移量不会只停留在局部 Widget 状态；
- 视口变化、场景重新上传、原生 renderer 重建后，仍可复用当前平移状态；
- 外部若使用导出的 `NativeCameraController`，也能读取和设置完整相机状态。

备选方案：
- 仅在 `_NativePcdTextureRenderer` 内维护平移：会在 renderer 同步或重建时丢失状态，也无法对外暴露。
- 仅在原生层维护平移：Flutter 层无法感知完整相机状态，状态源会分裂。

### 2. 继续复用 `GestureDetector.onScale*` 处理双指平移
保持现有手势入口不变，在 `pointerCount > 1` 时除了处理 `scale`，同时根据 `localFocalPoint` 位移累积 `panX` / `panY`。

这样改动最小，也能直接复用当前单指/双指手势分流逻辑。

备选方案：
- 改成自定义 `MultiDragGestureRecognizer` 或底层 `Listener` 指针追踪：可控性更高，但复杂度明显上升，超出这次需求。

### 3. 在视图矩阵中应用平移，而不是在模型矩阵中应用
原生渲染器应把 `panX` / `panY` 作为视图变换的一部分，与沿 z 轴的相机距离一起作用到 view matrix。这样平移方向会保持与屏幕坐标一致，不会因为模型旋转而出现“拖动方向跟着模型转”的体验。

备选方案：
- 在模型矩阵中平移：平移会受到后续旋转影响，手感不符合用户对双指拖动的预期。

### 4. 使用零值默认和可选参数保证 API 兼容
`panX` / `panY` 默认值为 `0`，并通过可选参数加入现有配置与控制器更新接口，避免对当前调用方造成破坏性影响。

## Risks / Trade-offs

- [平移速度手感不一致] → 使用与视口尺寸相关、且对缩放有感知的换算方式，并在 Android/iOS 实机上对近景和远景分别验证。
- [Android 与 iOS 渲染行为不一致] → 两端使用相同字段命名和相同矩阵应用顺序，避免平台分叉。
- [公开相机状态扩展后维护面变大] → 仅增加 `panX/panY` 两个最小必要字段，默认值为零，不引入额外控制接口。

## Migration Plan

1. 在 Flutter 相机配置和控制器中加入 `panX/panY`，默认值为零。
2. 扩展 `PcdView` 和 `NativeRendererBridge.updateCamera` 的相机同步参数。
3. 更新 Android/iOS 原生 `updateCamera` 和矩阵构造逻辑，使平移与旋转、缩放共同生效。
4. 调整 `_NativePcdTextureRenderer` 的双指手势更新逻辑，并验证单指旋转、双指缩放、双指平移互不回归。
5. 如需回滚，可忽略新增平移字段并移除矩阵平移逻辑，现有旋转/缩放行为可恢复到当前实现。

## Open Questions

- 双指平移的像素位移到世界坐标位移的换算常量最终取值是多少更合适。
- 是否需要在后续版本为平移增加公开的重置接口；本次先不纳入范围。
