import 'dart:math' as math;

import 'package:flutter/gestures.dart';

class TrackballOrientation {
  final double x;
  final double y;
  final double z;
  final double w;

  const TrackballOrientation(this.x, this.y, this.z, this.w);

  factory TrackballOrientation.identity() =>
      const TrackballOrientation(0, 0, 0, 1);

  factory TrackballOrientation.fromEuler({
    required double rotationX,
    required double rotationY,
  }) {
    final halfX = rotationX / 2;
    final halfY = rotationY / 2;
    final sx = math.sin(halfX);
    final cx = math.cos(halfX);
    final sy = math.sin(halfY);
    final cy = math.cos(halfY);
    return TrackballOrientation(sx * cy, cx * sy, -sx * sy, cx * cy);
  }

  List<double> toList() => [x, y, z, w];

  TrackballOrientation drag({
    required Offset from,
    required Offset to,
    required double aspectRatio,
    required double sensitivity,
  }) {
    final start = _project(from, aspectRatio);
    final end = _project(to, aspectRatio);
    final axisX = start.dy * end.dz - start.dz * end.dy;
    final axisY = start.dz * end.dx - start.dx * end.dz;
    final axisZ = start.dx * end.dy - start.dy * end.dx;
    final dot = (start.dx * end.dx + start.dy * end.dy + start.dz * end.dz)
        .clamp(-1.0, 1.0);
    final halfAngle = math.acos(dot) * sensitivity / 2;
    final axisLength = math.sqrt(axisX * axisX + axisY * axisY + axisZ * axisZ);
    if (axisLength == 0 || halfAngle == 0) return this;

    final scale = math.sin(halfAngle) / axisLength;
    final delta = TrackballOrientation(
      axisX * scale,
      axisY * scale,
      axisZ * scale,
      math.cos(halfAngle),
    );
    return delta._multiply(this)._normalized();
  }

  TrackballOrientation _multiply(TrackballOrientation other) {
    return TrackballOrientation(
      w * other.x + x * other.w + y * other.z - z * other.y,
      w * other.y - x * other.z + y * other.w + z * other.x,
      w * other.z + x * other.y - y * other.x + z * other.w,
      w * other.w - x * other.x - y * other.y - z * other.z,
    );
  }

  TrackballOrientation _normalized() {
    final length = math.sqrt(x * x + y * y + z * z + w * w);
    return TrackballOrientation(x / length, y / length, z / length, w / length);
  }

  static _Vector3 _project(Offset point, double aspectRatio) {
    final x = (point.dx - 0.5) * 2;
    final y = (0.5 - point.dy) * 2;
    final scaledX = x * (aspectRatio > 1 ? aspectRatio : 1);
    final scaledY = y * (aspectRatio < 1 ? 1 / aspectRatio : 1);
    final distance = scaledX * scaledX + scaledY * scaledY;
    if (distance <= 1) {
      return _Vector3(scaledX, scaledY, math.sqrt(1 - distance));
    }
    final length = math.sqrt(distance);
    return _Vector3(scaledX / length, scaledY / length, 0);
  }

  @override
  bool operator ==(Object other) =>
      other is TrackballOrientation &&
      x == other.x &&
      y == other.y &&
      z == other.z &&
      w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}

class _Vector3 {
  final double dx;
  final double dy;
  final double dz;

  const _Vector3(this.dx, this.dy, this.dz);
}
