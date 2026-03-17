## 1. 配置模型扩展

- [x] 1.1 在 `lib/src/config/viewer_config.dart` 中增加点颜色配置、默认值与 `copyWith` / 相等性支持
- [x] 1.2 在渲染链中接入点颜色默认值逻辑，确保未携带自定义颜色的点使用配置颜色显示

## 2. 设置页与持久化

- [x] 2.1 在 `example/lib/config/viewer_config_notifier.dart` 中增加点颜色的序列化、反序列化与更新方法
- [x] 2.2 在 `example/lib/screens/settings_screen.dart` 的“背景颜色”下方新增“点颜色”设置入口

## 3. 验证与文档同步

- [x] 3.1 验证修改点颜色后查看器渲染结果会更新，且不影响已有背景颜色设置
- [x] 3.2 验证点颜色设置在 example 中能正确持久化恢复
