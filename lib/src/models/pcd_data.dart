/// PCD 文件元数据
///
/// 包含 PCD 文件的头部信息和统计数据
class PcdMetadata {
  /// 文件版本
  final String version;

  /// 字段名称列表 (如 ["x", "y", "z", "rgb"])
  final List<String> fields;

  /// 点云总数
  final int pointCount;

  /// 数据格式 ("ascii" 或 "binary")
  final String dataFormat;

  /// 点云宽度 (无序点云为点数,有序点云为列数)
  final int width;

  /// 点云高度 (无序点云为1,有序点云为行数)
  final int height;

  /// 是否包含颜色信息
  final bool hasColor;

  const PcdMetadata({
    required this.version,
    required this.fields,
    required this.pointCount,
    required this.dataFormat,
    required this.width,
    required this.height,
    required this.hasColor,
  });

  /// 是否为有序点云 (organized point cloud)
  bool get isOrganized => height > 1;

  /// 是否为 ASCII 格式
  bool get isAscii => dataFormat.toLowerCase() == 'ascii';

  /// 是否为 Binary 格式
  bool get isBinary => dataFormat.toLowerCase() == 'binary';

  @override
  String toString() {
    return 'PcdMetadata('
        'version: $version, '
        'fields: $fields, '
        'points: $pointCount, '
        'format: $dataFormat, '
        'size: ${width}x$height, '
        'hasColor: $hasColor'
        ')';
  }
}

/// PCD 数据容器
///
/// 包含解析后的点云数据和元数据
class PcdData {
  /// 点云数据列表
  final List<dynamic> points;

  /// 文件元数据
  final PcdMetadata? metadata;

  const PcdData({
    required this.points,
    this.metadata,
  });

  /// 点云数量
  int get pointCount => points.length;

  /// 是否为空
  bool get isEmpty => points.isEmpty;

  /// 是否非空
  bool get isNotEmpty => points.isNotEmpty;

  @override
  String toString() {
    return 'PcdData(points: $pointCount, metadata: $metadata)';
  }
}
