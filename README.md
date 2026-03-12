# Flutter PCD View

高性能的 Flutter 点云数据查看器库，使用 Rust FFI 实现 PCD 文件解析。

## 特性

- ✅ 高性能 Rust 解析引擎
- ✅ 支持 ASCII 和 Binary PCD 格式
- ✅ 支持 XYZ、XYZRGB、XYZHSV 字段类型
- ✅ 交互式 3D 查看（旋转、缩放、平移）
- ✅ 可配置的查看器选项
- ✅ 点云优化（去重、体素下采样、最大点数限制）
- ✅ 跨平台支持（Android、iOS）

## 安装

```yaml
dependencies:
  flutter_pcd_view: ^0.0.1
```

## 快速开始

```dart
import 'package:flutter_pcd_view/pcd_view.dart';

// 从文件路径加载
PcdView.fromFile(
  filePath: '/path/to/file.pcd',
  config: ViewerConfig(
    pointSize: 2.0,
    showAxes: true,
    backgroundColor: Colors.black,
  ),
)

// 从预解析数据加载
final points = parsePcd(path: '/path/to/file.pcd');
PcdView.fromPoints(
  points: points,
  config: ViewerConfig(
    pointSize: 3.0,
    grid: GridConfig(
      visible: true,
      range: 10.0,
    ),
  ),
)
```

## 性能优化

对于大型点云文件（百万级点），可以使用 `PerformanceConfig` 进行优化：

```dart
PcdView.fromFile(
  filePath: '/path/to/large_file.pcd',
  config: ViewerConfig(
    performance: PerformanceConfig(
      enableDeduplication: true,    // 启用去重
      dedupPrecision: 0.001,        // 去重精度（米）
      voxelSize: 0.1,               // 体素大小（米），0 = 禁用
      maxPoints: 100000,            // 最大点数，0 = 无限制
    ),
  ),
  onOptimized: (stats) {
    print('原始点数: ${stats.originalCount}');
    print('优化后: ${stats.finalCount}');
    print('减少: ${(stats.reductionRatio * 100).toStringAsFixed(1)}%');
  },
)
```

### 优化选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `enableDeduplication` | 使用空间哈希去除重复点 | `false` |
| `dedupPrecision` | 去重精度（网格单元大小，单位：米） | `0.001` |
| `voxelSize` | 体素大小（Voxel Grid 下采样），0 = 禁用 | `0.0` |
| `maxPoints` | 最大点数限制，超出时均匀采样，0 = 无限制 | `0` |

### 优化流程

优化按以下顺序执行：**去重 → 体素下采样 → 最大点数限制**

1. **去重**: 使用空间哈希 O(n) 算法去除重复点
2. **体素下采样**: 将空间划分为立方体网格，每个网格内的点替换为质心
3. **最大点数限制**: 如果点数仍超限，均匀采样以保留空间分布

## 配置选项

### ViewerConfig

- `pointSize`: 点大小（像素）
- `backgroundColor`: 背景颜色
- `showAxes`: 是否显示坐标轴
- `grid`: 网格配置
- `camera`: 相机配置
- `performance`: 性能优化配置

### PerformanceConfig

- `enableDeduplication`: 启用去重
- `dedupPrecision`: 去重精度
- `voxelSize`: 体素大小
- `maxPoints`: 最大点数

### GridConfig

- `visible`: 是否显示网格
- `range`: 网格范围
- `step`: 网格步长
- `color`: 网格颜色

### CameraConfig

- `rotationX/Y`: 初始旋转角度
- `zoom`: 初始缩放
- `minZoom/maxZoom`: 缩放限制

## 示例

查看 `example/` 目录获取完整的示例应用。

## 许可证

MIT
