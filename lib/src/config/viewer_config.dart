import 'package:flutter/material.dart';

/// 点云性能优化配置
class PerformanceConfig {
  /// 启用去重（空间哈希）
  final bool enableDeduplication;

  /// 去重精度（网格单元大小，单位：米）
  final double dedupPrecision;

  /// 体素大小用于下采样（0 = 禁用）
  final double voxelSize;

  /// 最大点数（0 = 无限制）
  final int maxPoints;

  const PerformanceConfig({
    this.enableDeduplication = false,
    this.dedupPrecision = 0.001,
    this.voxelSize = 0.0,
    this.maxPoints = 0,
  });

  /// 是否启用任何优化
  bool get isEnabled =>
      enableDeduplication || voxelSize > 0.0 || maxPoints > 0;

  PerformanceConfig copyWith({
    bool? enableDeduplication,
    double? dedupPrecision,
    double? voxelSize,
    int? maxPoints,
  }) {
    return PerformanceConfig(
      enableDeduplication: enableDeduplication ?? this.enableDeduplication,
      dedupPrecision: dedupPrecision ?? this.dedupPrecision,
      voxelSize: voxelSize ?? this.voxelSize,
      maxPoints: maxPoints ?? this.maxPoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceConfig &&
          runtimeType == other.runtimeType &&
          enableDeduplication == other.enableDeduplication &&
          dedupPrecision == other.dedupPrecision &&
          voxelSize == other.voxelSize &&
          maxPoints == other.maxPoints;

  @override
  int get hashCode => Object.hash(
        enableDeduplication,
        dedupPrecision,
        voxelSize,
        maxPoints,
      );
}

/// 统计离群点去除（SOR）配置
class SORConfig {
  /// 近邻数量
  final int k;

  /// 标准差倍数阈值
  final double stdRatio;

  const SORConfig({
    this.k = 50,
    this.stdRatio = 1.0,
  });

  SORConfig copyWith({
    int? k,
    double? stdRatio,
  }) {
    return SORConfig(
      k: k ?? this.k,
      stdRatio: stdRatio ?? this.stdRatio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SORConfig &&
          runtimeType == other.runtimeType &&
          k == other.k &&
          stdRatio == other.stdRatio;

  @override
  int get hashCode => Object.hash(k, stdRatio);
}

/// 半径离群点去除（ROR）配置
class RORConfig {
  /// 搜索半径（单位：米）
  final double radius;

  /// 最小邻居数
  final int minNeighbors;

  const RORConfig({
    this.radius = 0.1,
    this.minNeighbors = 5,
  });

  RORConfig copyWith({
    double? radius,
    int? minNeighbors,
  }) {
    return RORConfig(
      radius: radius ?? this.radius,
      minNeighbors: minNeighbors ?? this.minNeighbors,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RORConfig &&
          runtimeType == other.runtimeType &&
          radius == other.radius &&
          minNeighbors == other.minNeighbors;

  @override
  int get hashCode => Object.hash(radius, minNeighbors);
}

/// 连接模式
enum ConnectMode {
  /// 无连接（仅点）
  none,
  /// 顺序连接（按文件顺序）
  sequential,
  /// 近邻连接
  nearestNeighbor,
}

/// 点连接配置
class ConnectConfig {
  /// 连接模式
  final ConnectMode mode;

  /// 最大连接距离（近邻模式）
  final double maxDistance;

  /// 最大线段数（顺序模式）
  final int maxSegments;

  const ConnectConfig({
    this.mode = ConnectMode.none,
    this.maxDistance = 0.5,
    this.maxSegments = 100000,
  });

  /// 是否启用连接
  bool get isEnabled => mode != ConnectMode.none;

  ConnectConfig copyWith({
    ConnectMode? mode,
    double? maxDistance,
    int? maxSegments,
  }) {
    return ConnectConfig(
      mode: mode ?? this.mode,
      maxDistance: maxDistance ?? this.maxDistance,
      maxSegments: maxSegments ?? this.maxSegments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectConfig &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          maxDistance == other.maxDistance &&
          maxSegments == other.maxSegments;

  @override
  int get hashCode => Object.hash(mode, maxDistance, maxSegments);
}

/// 点云高级处理配置
class ProcessingConfig {
  /// SOR 配置（null = 禁用）
  final SORConfig? sor;

  /// ROR 配置（null = 禁用）
  final RORConfig? ror;

  /// 连接配置（null = 禁用）
  final ConnectConfig? connect;

  const ProcessingConfig({
    this.sor,
    this.ror,
    this.connect,
  });

  /// 是否启用任何处理
  bool get isEnabled => sor != null || ror != null || (connect?.isEnabled ?? false);

  ProcessingConfig copyWith({
    SORConfig? sor,
    RORConfig? ror,
    ConnectConfig? connect,
  }) {
    return ProcessingConfig(
      sor: sor ?? this.sor,
      ror: ror ?? this.ror,
      connect: connect ?? this.connect,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingConfig &&
          runtimeType == other.runtimeType &&
          sor == other.sor &&
          ror == other.ror &&
          connect == other.connect;

  @override
  int get hashCode => Object.hash(sor, ror, connect);
}

/// 相机初始配置
class CameraConfig {
  /// 初始旋转 X 角度（弧度）
  final double rotationX;

  /// 初始旋转 Y 角度（弧度）
  final double rotationY;

  /// 初始缩放
  final double zoom;

  /// 最小缩放
  final double minZoom;

  /// 最大缩放
  final double maxZoom;

  const CameraConfig({
    this.rotationX = -0.3,
    this.rotationY = 0.5,
    this.zoom = 1.0,
    this.minZoom = 0.1,
    this.maxZoom = 10.0,
  });

  CameraConfig copyWith({
    double? rotationX,
    double? rotationY,
    double? zoom,
    double? minZoom,
    double? maxZoom,
  }) {
    return CameraConfig(
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
    );
  }
}

/// 网格配置
class GridConfig {
  /// 是否显示网格
  final bool visible;

  /// 网格范围（单位：米）
  final double range;

  /// 网格步长
  final double step;

  /// 网格颜色
  final Color color;

  const GridConfig({
    this.visible = true,
    this.range = 10.0,
    this.step = 1.0,
    this.color = const Color(0x44888888),
  });

  GridConfig copyWith({
    bool? visible,
    double? range,
    double? step,
    Color? color,
  }) {
    return GridConfig(
      visible: visible ?? this.visible,
      range: range ?? this.range,
      step: step ?? this.step,
      color: color ?? this.color,
    );
  }
}

/// PcdView 查看器配置
///
/// 控制点云查看器的外观和行为
class ViewerConfig {
  /// 点大小（像素）
  final double pointSize;

  /// 背景颜色
  final Color backgroundColor;

  /// 是否显示坐标轴
  final bool showAxes;

  /// 网格配置
  final GridConfig grid;

  /// 相机配置
  final CameraConfig camera;

  /// 性能优化配置
  final PerformanceConfig performance;

  /// 高级处理配置
  final ProcessingConfig processing;

  const ViewerConfig({
    this.pointSize = 2.0,
    this.backgroundColor = Colors.black,
    this.showAxes = true,
    this.grid = const GridConfig(),
    this.camera = const CameraConfig(),
    this.performance = const PerformanceConfig(),
    this.processing = const ProcessingConfig(),
  });

  ViewerConfig copyWith({
    double? pointSize,
    Color? backgroundColor,
    bool? showAxes,
    GridConfig? grid,
    CameraConfig? camera,
    PerformanceConfig? performance,
    ProcessingConfig? processing,
  }) {
    return ViewerConfig(
      pointSize: pointSize ?? this.pointSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showAxes: showAxes ?? this.showAxes,
      grid: grid ?? this.grid,
      camera: camera ?? this.camera,
      performance: performance ?? this.performance,
      processing: processing ?? this.processing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerConfig &&
          runtimeType == other.runtimeType &&
          pointSize == other.pointSize &&
          backgroundColor == other.backgroundColor &&
          showAxes == other.showAxes &&
          performance == other.performance &&
          processing == other.processing;

  @override
  int get hashCode => Object.hash(pointSize, backgroundColor, showAxes, performance, processing);
}
