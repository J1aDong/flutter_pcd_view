## 1. Rust 解析器基础设置

- [x] 1.1 创建 rust/ 目录结构和 Cargo.toml 配置
- [x] 1.2 添加 flutter_rust_bridge 依赖到 pubspec.yaml
- [x] 1.3 配置 Android NDK 编译支持（build.gradle）
- [x] 1.4 配置 iOS 静态库编译支持（Podfile）
- [x] 1.5 创建 Rust 项目基础文件（lib.rs, parser.rs）

## 2. Rust PCD 解析器实现

- [x] 2.1 实现 PCD 文件头解析（VERSION, FIELDS, SIZE, TYPE, COUNT, WIDTH, HEIGHT, POINTS, DATA）
- [x] 2.2 实现字段类型检测（XYZ, XYZRGB, XYZHSV）
- [x] 2.3 实现 ASCII 格式点云数据解析
- [x] 2.4 实现 Binary 格式点云数据解析
- [x] 2.5 实现 RGB 颜色格式转换（decimal to ARGB u32）
- [x] 2.6 实现错误处理和验证（无效文件格式、不支持的字段类型）
- [x] 2.7 添加 Rust 单元测试（解析各种 PCD 格式）

## 3. FFI 桥接层

- [x] 3.1 使用 flutter_rust_bridge_codegen 生成 Dart 绑定代码
- [x] 3.2 创建 lib/src/parser/pcd_parser.dart FFI 接口
- [x] 3.3 实现 Dart 侧错误处理包装
- [ ] 3.4 验证 Android 平台 FFI 调用
- [ ] 3.5 验证 iOS 平台 FFI 调用

## 4. 数据模型层

- [x] 4.1 创建 lib/src/models/point_3d.dart 点云数据模型
- [x] 4.2 创建 lib/src/models/pcd_data.dart PCD 元数据模型
- [x] 4.3 实现 Rust Point3D 到 Dart Point3D 的转换
- [x] 4.4 实现 DiTreDi Point3D 适配器

## 5. 查看器配置层

- [x] 5.1 创建 lib/src/config/viewer_config.dart 配置类
- [x] 5.2 实现 pointSize 配置
- [x] 5.3 实现 grid 配置（范围、可见性）
- [x] 5.4 实现 backgroundColor 配置
- [x] 5.5 实现 showAxes 配置
- [x] 5.6 实现 camera 配置（初始旋转、缩放、缩放限制）

## 6. PcdView Widget 实现

- [x] 6.1 创建 lib/src/widgets/pcd_view_widget.dart 基础结构
- [x] 6.2 实现从文件路径加载 PCD 的构造函数
- [x] 6.3 实现从预解析数据加载的构造函数
- [x] 6.4 集成 DiTreDi 渲染引擎
- [x] 6.5 实现手势控制（拖拽旋转、捏合缩放）
- [x] 6.6 实现鼠标滚轮缩放支持
- [x] 6.7 实现 Grid3D 渲染（基于配置）
- [x] 6.8 实现 GuideAxis3D 渲染（基于配置）
- [x] 6.9 实现 PointCloud3D 渲染（基于配置的点大小）
- [x] 6.10 实现自定义 DiTreDiController 支持
- [x] 6.11 实现 ViewerConfig 响应式更新

## 7. 库导出和文档

- [x] 7.1 创建 lib/pcd_view.dart 主导出文件
- [x] 7.2 导出 PcdView widget
- [x] 7.3 导出 ViewerConfig 类
- [x] 7.4 导出必要的数据模型
- [x] 7.5 编写 API 文档注释（dartdoc）
- [x] 7.6 创建 README.md（安装、使用示例、配置说明）
- [x] 7.7 创建 CHANGELOG.md

## 8. Demo 应用 - 文件选择功能

- [x] 8.1 创建 example/lib/screens/file_select_screen.dart
- [x] 8.2 集成 file_picker 依赖
- [x] 8.3 实现本地文件浏览 UI
- [x] 8.4 实现单文件选择功能
- [x] 8.5 实现多文件选择功能
- [x] 8.6 实现文件列表显示

## 9. Demo 应用 - 查看器设置功能

- [x] 9.1 创建 example/lib/screens/settings_screen.dart
- [x] 9.2 实现点大小调整 slider
- [x] 9.3 实现网格范围输入框
- [x] 9.4 实现背景色选择器
- [x] 9.5 实现网格可见性开关
- [x] 9.6 实现坐标轴可见性开关
- [x] 9.7 实现设置持久化（shared_preferences）

## 10. Demo 应用 - 查看器界面

- [x] 10.1 创建 example/lib/screens/viewer_screen.dart
- [x] 10.2 集成 PcdView widget
- [x] 10.3 实现单文件查看模式
- [x] 10.4 实现多文件序列播放模式（Timer-based, ~30 FPS）
- [x] 10.5 实现播放进度显示（当前帧/总帧数）
- [x] 10.6 实现侧边栏控制（点大小增减按钮）
- [x] 10.7 实现返回导航（保留相机状态）
- [x] 10.8 实现 AppBar 标题动态显示（文件名/播放进度）

## 11. Demo 应用 - 主界面和导航

- [x] 11.1 创建 example/lib/main.dart 入口
- [x] 11.2 实现 Tab 导航结构（文件选择 / 设置）
- [x] 11.3 实现页面路由（文件选择 → 查看器）
- [x] 11.4 实现 ViewerConfig 状态管理（GetX 或 Provider）
- [x] 11.5 复制 PointCloudDataViewer 的 UI 样式

## 12. 测试和验证

- [x] 12.1 准备测试 PCD 文件（XYZ, XYZRGB, ASCII, Binary）
- [ ] 12.2 测试 Android 真机运行
- [ ] 12.3 测试 iOS 真机运行
- [ ] 12.4 测试大文件性能（100K+ 点）
- [ ] 12.5 测试多文件播放功能
- [ ] 12.6 测试手势交互流畅度
- [ ] 12.7 运行 flutter analyze 检查代码质量
- [ ] 12.8 修复所有 lint 警告

## 13. 发布准备

- [ ] 13.1 更新 pubspec.yaml 版本号和描述
- [ ] 13.2 添加 LICENSE 文件
- [ ] 13.3 添加 example/ 的 README
- [ ] 13.4 创建 screenshots 用于文档
- [ ] 13.5 验证 pub.dev 发布检查（flutter pub publish --dry-run）
