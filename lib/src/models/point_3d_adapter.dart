import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'point_3d.dart';
import '../ffi/parser.dart' as ffi;

/// Point3D 适配器
///
/// 提供 FFI Point3D 和 DiTreDi Point3D 之间的转换
class Point3DAdapter {
  /// 从 FFI Point3D 转换为 Dart Point3DModel
  static Point3DModel fromFfi(ffi.Point3D ffiPoint) {
    return Point3DModel(
      x: ffiPoint.x,
      y: ffiPoint.y,
      z: ffiPoint.z,
      color: ffiPoint.color,
    );
  }

  /// 从 FFI Point3D 列表批量转换
  static List<Point3DModel> fromFfiList(List<ffi.Point3D> ffiPoints) {
    return ffiPoints.map(fromFfi).toList();
  }

  /// 转换为 DiTreDi Point3D
  static Point3D toDitredi(Point3DModel point, {double pointSize = 2.0}) {
    return Point3D(
      Vector3(point.x, point.y, point.z),
      width: pointSize,
      color: Color(point.color),
    );
  }

  /// 批量转换为 DiTreDi Point3D
  static List<Point3D> toDitrediList(
    List<Point3DModel> points, {
    double pointSize = 2.0,
  }) {
    return points.map((p) => toDitredi(p, pointSize: pointSize)).toList();
  }

  /// 直接从 FFI 转换为 DiTreDi (性能优化)
  static Point3D ffiToDitredi(ffi.Point3D ffiPoint, {double pointSize = 2.0}) {
    return Point3D(
      Vector3(ffiPoint.x, ffiPoint.y, ffiPoint.z),
      width: pointSize,
      color: Color(ffiPoint.color),
    );
  }

  /// 批量从 FFI 转换为 DiTreDi (性能优化)
  static List<Point3D> ffiToDitrediList(
    List<ffi.Point3D> ffiPoints, {
    double pointSize = 2.0,
  }) {
    return ffiPoints.map((p) => ffiToDitredi(p, pointSize: pointSize)).toList();
  }

  /// 计算点云边界框
  static Aabb3 calculateBounds(List<Point3DModel> points) {
    if (points.isEmpty) {
      return Aabb3.minMax(Vector3.zero(), Vector3.zero());
    }

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;
    double minZ = points.first.z;
    double maxZ = points.first.z;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
      if (point.z < minZ) minZ = point.z;
      if (point.z > maxZ) maxZ = point.z;
    }

    return Aabb3.minMax(
      Vector3(minX, minY, minZ),
      Vector3(maxX, maxY, maxZ),
    );
  }

  /// 计算点云中心点
  static Vector3 calculateCenter(List<Point3DModel> points) {
    if (points.isEmpty) return Vector3.zero();

    final bounds = calculateBounds(points);
    return bounds.center;
  }

  /// 计算点云最大范围 (用于自动缩放)
  static double calculateMaxRange(List<Point3DModel> points) {
    if (points.isEmpty) return 1.0;

    final bounds = calculateBounds(points);
    final size = bounds.max - bounds.min;
    return [size.x, size.y, size.z].reduce((a, b) => a > b ? a : b);
  }
}
