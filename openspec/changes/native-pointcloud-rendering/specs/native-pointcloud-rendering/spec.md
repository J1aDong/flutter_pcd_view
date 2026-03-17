## ADDED Requirements

### Requirement: PcdView SHALL use native texture rendering on mobile
`PcdView` 在 Android 和 iOS 上 SHALL 统一通过原生 texture 渲染点云，不得再依赖 Flutter Canvas 或 `DiTreDi` 作为点云主绘制路径。

#### Scenario: Render file-based point cloud through native texture
- **WHEN** 调用方使用 `PcdView.fromFile` 加载点云文件
- **THEN** 点云 SHALL 通过原生 texture 渲染显示在 Flutter `Texture()` 中

#### Scenario: Render in-memory point cloud through native texture
- **WHEN** 调用方使用 `PcdView.fromPoints` 提供预解析点云数据
- **THEN** 点数据 SHALL 通过紧凑缓冲上传进入 native renderer 并显示在 Flutter `Texture()` 中

### Requirement: Native renderer SHALL preserve interactive camera control
原生渲染器 SHALL 支持与当前查看器等价的相机交互，包括旋转、缩放以及必要的平移能力。

#### Scenario: Rotate point cloud from Flutter gestures
- **WHEN** 用户在 `PcdView` 上执行拖拽旋转手势
- **THEN** Flutter SHALL 将相机变化发送给 native renderer，且原生纹理中的点云视角 SHALL 实时更新

#### Scenario: Zoom point cloud from Flutter gestures
- **WHEN** 用户在 `PcdView` 上执行滚轮或捏合缩放操作
- **THEN** native renderer SHALL 按新的缩放参数重绘点云而不依赖 Flutter 侧重建点模型

### Requirement: Native renderer SHALL report initialization and runtime errors
原生渲染器在初始化失败、surface 丢失、图形上下文异常或点缓冲上传失败时 SHALL 向 Flutter 暴露明确错误，而不是静默回退到旧渲染链。

#### Scenario: Report native initialization failure
- **WHEN** native texture 或图形上下文初始化失败
- **THEN** `PcdView` SHALL 进入错误状态并向调用方返回可读的错误信息

#### Scenario: Report point upload failure
- **WHEN** `fromPoints` 或 `fromFile` 对应的点缓冲上传失败
- **THEN** `PcdView` SHALL 停止进入 ready 状态并返回上传失败原因

### Requirement: Native renderer SHALL support viewer visual configuration
原生渲染器 SHALL 支持查看器的关键视觉配置，包括背景色、点大小、网格、坐标轴以及连线段显示。

#### Scenario: Apply point size and background color
- **WHEN** 调用方更新点大小和背景色配置
- **THEN** native renderer SHALL 在下一帧使用新的点大小和背景色渲染

#### Scenario: Toggle grid and axes visibility
- **WHEN** 调用方切换网格或坐标轴显示配置
- **THEN** 原生纹理中的网格和坐标轴 SHALL 与配置状态保持一致
