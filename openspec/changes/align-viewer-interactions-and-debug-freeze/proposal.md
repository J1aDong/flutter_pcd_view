## Why

当前 `pointcloud_map.pcd` 在 demo 查看器中进入后基本失去交互能力，返回也会明显阻塞；这说明当前大文件加载与渲染路径会拖住 UI。与此同时，现有查看器交互没有完整对齐参考项目 `/Users/mr.j/myRoom/code/flutter/PointCloudDataViewer_flutter-main` 中已验证过的旋转、缩放和查看控制体验，因此需要先补齐交互能力，再把大文件路径做成可观测、可定位、可优化的状态。

## What Changes

- 为查看器补齐与参考项目一致的核心交互能力，包括拖拽旋转、捏合缩放、滚轮缩放及稳定的相机状态维护。
- 重构大文件 PCD 的加载/显示链路，避免打开大文件或退出查看器时长时间阻塞主界面。
- 为解析、场景构建、屏幕切换、取消返回等关键路径补充结构化调试日志，方便定位卡死点。
- 更新 demo 查看器界面的加载态、错误态与控制反馈，使用户在大文件场景下知道当前阶段而不是看到“假死”画面。

## Capabilities

### New Capabilities
- `viewer-interaction-parity`: 让查看器交互与参考应用对齐，支持可预期的旋转、缩放与控制反馈。
- `responsive-pcd-loading`: 让大体积 PCD 文件加载与退出查看器时保持界面响应，不再长时间卡住主线程体验。
- `viewer-diagnostics`: 为查看器关键阶段提供可筛选的调试日志，便于定位解析、渲染和导航卡顿。

### Modified Capabilities
<!-- None -->

## Impact

- `lib/src/widgets/pcd_view_widget.dart`：查看器加载链路、交互层、状态反馈。
- `lib/src/ffi/` 与 `lib/src/parser/`：PCD 解析调用方式、异步/后台执行策略、阶段性日志。
- `example/lib/screens/viewer_screen.dart`：demo 控制入口、加载提示、返回体验与参考项目交互对齐。
- `example/lib/screens/file_select_screen.dart`：打开大文件前后的状态衔接与错误提示。
- 调试与验证流程：需要针对大文件、返回导航和交互流畅度补充验证项。
