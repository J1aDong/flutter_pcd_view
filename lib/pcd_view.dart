/// Flutter PCD View - 高性能点云数据查看器
///
/// 提供基于 Rust 解析引擎的 PCD 文件查看 Widget，
/// 支持 ASCII 和 Binary 格式，支持 XYZ、XYZRGB、XYZHSV 字段类型。
///
/// ## 快速开始
///
/// ```dart
/// import 'package:flutter_pcd_view/pcd_view.dart';
///
/// // 从文件路径加载
/// PcdView.fromFile(
///   filePath: '/path/to/file.pcd',
///   config: ViewerConfig(
///     pointSize: 2.0,
///     showAxes: true,
///   ),
/// )
///
/// // 从预解析数据加载
/// PcdView.fromPoints(
///   points: parsedPoints,
///   config: ViewerConfig(
///     backgroundColor: Colors.black,
///   ),
/// )
/// ```
library;

// Widget
export 'src/widgets/pcd_view_widget.dart';

// 配置
export 'src/config/viewer_config.dart';

// 数据模型
export 'src/models/point_3d.dart';
export 'src/models/pcd_data.dart';
export 'src/models/point_3d_adapter.dart';

// FFI 接口
export 'src/ffi/api.dart';
export 'src/ffi/parser.dart';
export 'src/ffi/frb.dart' show PcdParser;
