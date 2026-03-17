import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pcd_view/flutter_pcd_view.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

void main() {
  test('Point3D creation', () {
    final point = Point3D(
      x: 1.0,
      y: 2.0,
      z: 3.0,
      color: 0xFFFFFFFF,
      hasColor: true,
    );
    expect(point.x, 1.0);
    expect(point.y, 2.0);
    expect(point.z, 3.0);
    expect(point.color, 0xFFFFFFFF);
    expect(point.hasColor, true);
  });

  test('ViewerConfig supports pointColor in defaults and copyWith', () {
    const config = ViewerConfig();
    expect(config.pointColor, Colors.white);

    final updated = config.copyWith(pointColor: Colors.red);
    expect(updated.pointColor, Colors.red);
    expect(updated, const ViewerConfig(pointColor: Colors.red));
  });
}
