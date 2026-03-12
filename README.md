# Flutter PCD View

高性能的 Flutter 点云数据查看器库，使用 Rust FFI 实现 PCD 文件解析。

## 特性

- ✅ 高性能 Rust 解析引擎
- ✅ 支持 ASCII 和 Binary PCD 格式
- ✅ 支持 XYZ、XYZRGB、XYZHSV 字段类型
- ✅ 交互式 3D 查看（旋转、缩放、平移）
- ✅ 可配置的查看器选项
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

## 配置选项

### ViewerConfig

- `pointSize`: 点大小（像素）
- `backgroundColor`: 背景颜色
- `showAxes`: 是否显示坐标轴
- `grid`: 网格配置
- `camera`: 相机配置

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
