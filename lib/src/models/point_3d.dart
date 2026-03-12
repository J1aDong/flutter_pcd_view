import 'package:flutter/material.dart';

/// 3D 点云数据模型
///
/// 表示点云中的单个点,包含空间坐标和颜色信息
class Point3DModel {
  /// X 坐标
  final double x;

  /// Y 坐标
  final double y;

  /// Z 坐标
  final double z;

  /// 颜色值 (ARGB 格式: 0xAARRGGBB)
  final int color;

  const Point3DModel({
    required this.x,
    required this.y,
    required this.z,
    required this.color,
  });

  /// 从 FFI Point3D 转换
  factory Point3DModel.fromFfi(dynamic ffiPoint) {
    return Point3DModel(
      x: ffiPoint.x as double,
      y: ffiPoint.y as double,
      z: ffiPoint.z as double,
      color: ffiPoint.color as int,
    );
  }

  /// 获取 Flutter Color 对象
  Color get flutterColor => Color(color);

  /// 复制并修改部分属性
  Point3DModel copyWith({
    double? x,
    double? y,
    double? z,
    int? color,
  }) {
    return Point3DModel(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point3DModel &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z &&
          color == other.color;

  @override
  int get hashCode => Object.hash(x, y, z, color);

  @override
  String toString() => 'Point3D(x: $x, y: $y, z: $z, color: 0x${color.toRadixString(16)})';
}
