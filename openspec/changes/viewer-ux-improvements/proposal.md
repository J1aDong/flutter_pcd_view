## Why

当前点云查看器存在多个 UX 问题影响用户体验：加载过程缺乏进度反馈、设置无法持久化、离群点去除开关无法关闭、处理算法性能问题导致长时间卡顿、文件选择器交互不合理。这些问题需要统一解决以提升整体用户体验。

## What Changes

- **加载状态展示**：在点云查看页面底部显示加载进度和错误信息
- **设置持久化**：使用 SharedPreferences 保存查看器设置，下次启动自动恢复
- **离群点开关修复**：修复 SOR/ROR 开关打开后无法关闭的问题
- **性能优化**：优化离群点去除算法性能，调整默认参数为更合理的值，添加性能测试
- **文件选择改进**：将多选 checkbox 改为单选模式，支持取消选中

## Capabilities

### New Capabilities

- `loading-progress-display`: 点云加载进度展示，包括进度条和错误信息显示
- `settings-persistence`: 设置持久化存储，使用 SharedPreferences 保存和恢复配置
- `outlier-removal-performance`: 离群点去除性能优化，包括算法优化和默认参数调整

### Modified Capabilities

- `outlier-removal-ui`: 修复 SOR/ROR 开关无法关闭的问题
- `file-selection-ui`: 修改文件选择交互为单选模式

## Impact

- **Flutter 端**：
  - `viewer_screen.dart` - 添加底部进度条组件
  - `settings_screen.dart` - 修复开关逻辑
  - `viewer_config_notifier.dart` - 添加持久化逻辑
  - `home_screen.dart` 或文件选择相关组件 - 修改选择交互

- **Rust 端**：
  - `processing/outlier.rs` - 性能优化
  - 添加性能测试用例

- **依赖**：
  - 需要添加 `shared_preferences` 包用于设置持久化
