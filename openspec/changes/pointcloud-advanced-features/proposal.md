## Why

当前点云查看器缺乏高级处理功能：无法将离散点连接成线（常用于激光雷达扫描线可视化）、缺乏杂点去除能力导致显示质量差、不支持点云融合显示多个数据源。这些是业界点云处理的常见需求。

## What Changes

- 新增点连线功能：基于 KD-Tree 近邻搜索或用户指定顺序，将离散点连接成连续线段
- 新增统计离群点去除（SOR）：业界标准算法，基于点密度统计过滤杂点
- 新增半径离群点去除（ROR）：基于局部邻域点数过滤孤立点
- 新增点云融合：支持多个点云合并显示，自动对齐坐标系

## Capabilities

### New Capabilities

- `point-connectivity`: 点连线功能 - 将离散点连接成线段显示，支持近邻自动连接和顺序连接模式
- `outlier-removal`: 杂点去除 - 统计离群点去除（SOR）和半径离群点去除（ROR）算法
- `pointcloud-merge`: 点云融合 - 多点云合并显示与坐标系对齐

### Modified Capabilities

- `viewer-performance-settings`: 扩展配置项以支持新增的高级处理选项

## Impact

- Rust 层新增模块：`rust/src/processing/` (connectivity, outlier, merge)
- FFI 接口扩展：新增处理配置和结果类型
- Flutter Widget：`PcdView` 支持线段渲染模式
- Example App：设置界面新增高级处理选项
