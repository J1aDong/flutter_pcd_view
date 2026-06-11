# Flutter PCD View

`flutter_pcd_view` is a Flutter plugin for viewing PCD point cloud files on Android and iOS. It uses Rust for PCD parsing and native rendering backends for interactive display: OpenGL ES on Android and Metal on iOS.

## Features

- Parse ASCII and binary PCD files.
- Display XYZ, XYZRGB, and XYZHSV point clouds.
- Render with mobile native textures on Android and iOS.
- Rotate, zoom, and pan with Flutter gestures.
- Optional point budget, voxel sampling, deduplication, outlier removal, grid, axes, and point color settings.

## Platform Support

Current rendering support is Android and iOS only. Other Flutter platforms return an unsupported-platform state instead of rendering a point cloud.

## Installation

```yaml
dependencies:
  flutter_pcd_view: ^0.1.6
```

## Quick Start

Import the main widget API:

```dart
import 'package:flutter_pcd_view/flutter_pcd_view.dart';
```

Use the default viewer directly:

```dart
PcdView.fromFile(filePath: '/path/to/file.pcd')
```

The parser initializes automatically when the viewer loads a file. For in-memory points, use:

```dart
PcdView.fromPoints(points: points)
```

## Optional Configuration

Defaults are intended to work without extra setup. Add a controller or config only when the host app needs custom camera state or rendering options:

```dart
final controller = NativeCameraController();

PcdView.fromFile(
  filePath: '/path/to/file.pcd',
  controller: controller,
  config: const ViewerConfig(
    pointSize: 2,
    showAxes: true,
    performance: PerformanceConfig(
      nativePointBudget: 150000,
      nativeRenderScale: 2,
    ),
  ),
)
```

## Example

See the `example/` directory for a complete Flutter app with bundled sample PCD files, file picking, settings, and native renderer status.

## License

MIT
