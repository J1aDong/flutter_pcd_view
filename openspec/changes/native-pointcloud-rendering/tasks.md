## 1. Android 原生渲染基础设施

- [x] 1.1 设计并实现 Rust 渲染核心的生命周期接口（先满足 Android 渲染链接入）
- [x] 1.2 在 Android 侧实现 texture 注册、surface 生命周期管理和 OpenGL ES 渲染承载
- [x] 1.3 打通 Flutter ↔ Android native ↔ Rust 的渲染控制桥接接口

## 2. 点云数据接入 native renderer

- [x] 2.1 将 `PcdView.fromFile` 接入 Rust 解析 + native renderer 渲染路径
- [x] 2.2 设计 `fromPoints` 的紧凑缓冲协议，避免对象级逐点传输
- [x] 2.3 将 `PcdView.fromPoints` 接入 native renderer 渲染路径
- [x] 2.4 在 native renderer 中支持点云、连线段、网格和坐标轴的统一场景绘制

## 3. Flutter 侧组件改造

- [x] 3.1 重构 `lib/src/widgets/pcd_view_widget.dart`，统一改为 `Texture()` 显示 native renderer 输出
- [x] 3.2 保留 Flutter 手势层，并将相机变化同步到 native renderer
- [x] 3.3 将背景色、点大小、网格、坐标轴等配置同步到 native renderer
- [x] 3.4 在 `PcdView` 中完善 native 初始化失败、上传失败和运行时异常的错误展示

## 4. 移除 Flutter/DiTreDi 渲染路径

- [ ] 4.1 删除 `DiTreDi` 渲染接入代码和 figures 组装逻辑
- [ ] 4.2 删除 `Point3DAdapter` 等仅服务于 Flutter 渲染路径的适配层
- [ ] 4.3 从 `pubspec.yaml` 中移除 `ditredi` 依赖及相关无用代码引用
- [ ] 4.4 清理与旧渲染路径相关的状态、日志和分支逻辑

## 5. 配置与示例应用同步

- [x] 5.1 扩展 `ViewerConfig` 与性能配置，使其适配 native renderer 所需参数
- [x] 5.2 更新 example 中的查看器页面，验证 native texture 渲染、状态展示和交互逻辑
- [x] 5.3 更新 example 中的设置页面，验证 native renderer 配置实时生效
- [ ] 5.4 补充 native-only 架构下的使用说明与限制说明

## 6. Android 验证与后续 iOS 计划

- [ ] 6.1 在 Android 真机验证 native texture 渲染、生命周期和内存释放
- [ ] 6.2 验证高点数场景下的旋转、缩放和切换文件流畅度
- [ ] 6.3 验证 `fromFile` 与 `fromPoints` 两种入口都能正确进入 Android native renderer
- [x] 6.4 运行 Flutter / Rust / Android 相关静态检查与测试，修复回归问题
- [ ] 6.5 在 Android 渲染链稳定后补齐 iOS Metal 的 texture 桥接与渲染实现
