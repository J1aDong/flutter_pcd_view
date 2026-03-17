## Context

当前点云查看器已完成核心功能实现，但存在以下 UX 问题：
1. 加载大文件时缺乏进度反馈，用户无法了解加载状态
2. 设置每次启动都会重置，无法保持用户偏好
3. SOR/ROR 开关存在 bug，打开后无法关闭
4. 离群点去除算法对大点云处理较慢，默认参数过于激进
5. 文件选择器允许多选但实际只能加载一个文件

## Goals / Non-Goals

**Goals:**
- 提供清晰的加载进度和错误反馈
- 实现设置持久化，提升用户体验
- 修复 SOR/ROR 开关无法关闭的 bug
- 优化离群点去除性能，调整默认参数
- 改进文件选择交互为单选模式

**Non-Goals:**
- 不修改点云渲染核心逻辑
- 不添加新的点云处理算法
- 不实现多点云合并加载功能

## Decisions

### 1. 加载进度展示方案

**决定**：在 ViewerScreen 底部添加一个可折叠的状态栏组件

**理由**：
- 不遮挡点云视图主体
- 可展示加载状态、进度百分比、错误信息
- 加载完成后自动隐藏

**替代方案**：
- 全屏遮罩 loading：会完全遮挡视图，体验差
- 顶部 SnackBar：不够显眼，容易被忽略

### 2. 设置持久化方案

**决定**：使用 `shared_preferences` 包存储 JSON 序列化的配置

**理由**：
- 轻量级，适合存储简单配置
- Flutter 官方推荐方案
- 支持所有平台

**存储结构**：
```json
{
  "pointSize": 2.0,
  "backgroundColor": 0xFF000000,
  "showAxes": true,
  "grid": { "visible": true, "range": 10.0 },
  "performance": { "enableDeduplication": false, ... },
  "processing": { "sor": null, "ror": null, "connect": null }
}
```

### 3. SOR/ROR 开关修复

**决定**：修改 `copyWith` 逻辑，当传入 `null` 时正确处理

**问题根因**：当前 `updateSOREnabled(false)` 会设置 `sor: null`，但 `copyWith` 可能未正确处理 `null` 值

### 4. 性能优化方案

**决定**：
1. 调整默认参数为更保守的值
2. 添加处理超时机制
3. 在 Rust 端添加性能测试

**默认参数调整**：
- SOR: k=50 → k=30, stdRatio=1.0 → stdRatio=2.0
- ROR: radius=0.1 → radius=0.05, minNeighbors=5 → minNeighbors=3

**理由**：更宽松的参数意味着处理更快，同时仍能去除明显的离群点

### 5. 文件选择方案

**决定**：使用 RadioListTile 替代 Checkbox，并添加"取消选择"选项

**理由**：
- 单选语义更清晰
- RadioListTile 自带选中/取消交互
- 可添加空选项让用户取消选择

## Risks / Trade-offs

### 风险1：设置持久化可能导致旧配置不兼容
- **缓解**：使用版本号，加载时检查版本，不兼容时使用默认值

### 风险2：性能优化可能降低离群点去除效果
- **缓解**：保留用户自定义参数的能力，默认值仅作为初始推荐

### 风险3：底部状态栏可能占用过多空间
- **缓解**：设计为紧凑模式，加载完成后自动收起
