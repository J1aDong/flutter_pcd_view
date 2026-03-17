## 1. 设置持久化

- [x] 1.1 添加 shared_preferences 依赖到 pubspec.yaml
- [x] 1.2 创建 SettingsService 类处理设置的保存和加载
- [x] 1.3 更新 ViewerConfigNotifier 集成 SettingsService
- [x] 1.4 实现设置的 JSON 序列化和反序列化
- [x] 1.5 添加版本兼容性处理逻辑

## 2. 加载进度展示

- [x] 2.1 创建 LoadingStatusBar 组件
- [x] 2.2 在 ViewerScreen 底部集成进度条
- [x] 2.3 实现加载状态和进度百分比显示
- [x] 2.4 实现错误信息的红色高亮显示
- [x] 2.5 实现处理统计信息的展示

## 3. 离群点开关修复

- [x] 3.1 分析 SOR/ROR copyWith 逻辑问题
- [x] 3.2 修复 ProcessingConfig.copyWith 处理 null 值
- [x] 3.3 修复 viewer_config_notifier.dart 中的开关逻辑
- [ ] 3.4 添加单元测试验证开关功能

## 4. 性能优化

- [x] 4.1 调整 SOR 默认参数 (k=30, stdRatio=2.0)
- [x] 4.2 调整 ROR 默认参数 (radius=0.05, minNeighbors=3)
- [ ] 4.3 在 Rust 端添加性能基准测试
- [ ] 4.4 优化 SOR 算法性能（如空间索引）
- [ ] 4.5 优化 ROR 算法性能（如空间索引）

## 5. 文件选择改进

- [x] 5.1 将 Checkbox 改为 RadioListTile
- [x] 5.2 实现点击已选中项取消选择
- [x] 5.3 无选中文件时禁用加载按钮
- [x] 5.4 更新选中状态的视觉样式

## 6. 测试验证

- [x] 6.1 运行 Flutter analyze 确保无错误
- [x] 6.2 运行 Rust 测试确保通过
- [ ] 6.3 手动测试所有新功能
- [ ] 6.4 验证设置持久化跨会话有效