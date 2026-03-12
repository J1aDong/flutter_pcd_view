import 'package:flutter/material.dart';

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

  const ViewerConfig({
    this.pointSize = 2.0,
    this.backgroundColor = Colors.black,
    this.showAxes = true,
    this.grid = const GridConfig(),
    this.camera = const CameraConfig(),
  });

  ViewerConfig copyWith({
    double? pointSize,
    Color? backgroundColor,
    bool? showAxes,
    GridConfig? grid,
    CameraConfig? camera,
  }) {
    return ViewerConfig(
      pointSize: pointSize ?? this.pointSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showAxes: showAxes ?? this.showAxes,
      grid: grid ?? this.grid,
      camera: camera ?? this.camera,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerConfig &&
          runtimeType == other.runtimeType &&
          pointSize == other.pointSize &&
          backgroundColor == other.backgroundColor &&
          showAxes == other.showAxes;

  @override
  int get hashCode => Object.hash(pointSize, backgroundColor, showAxes);
}
