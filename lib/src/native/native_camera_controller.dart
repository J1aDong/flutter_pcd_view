import 'package:flutter/foundation.dart';

class NativeCameraController extends ChangeNotifier {
  NativeCameraController({
    double rotationX = -0.3,
    double rotationY = 0.5,
    double userScale = 1.0,
    double minUserScale = 0.1,
    double maxUserScale = 10.0,
  })  : _rotationX = rotationX,
        _rotationY = rotationY,
        _userScale = userScale,
        _minUserScale = minUserScale,
        _maxUserScale = maxUserScale;

  double _rotationX;
  double _rotationY;
  double _userScale;
  double _minUserScale;
  double _maxUserScale;

  double get rotationX => _rotationX;
  double get rotationY => _rotationY;
  double get userScale => _userScale;
  double get minUserScale => _minUserScale;
  double get maxUserScale => _maxUserScale;

  void update({
    double? rotationX,
    double? rotationY,
    double? userScale,
    double? minUserScale,
    double? maxUserScale,
  }) {
    var changed = false;

    if (rotationX != null && rotationX != _rotationX) {
      _rotationX = rotationX;
      changed = true;
    }
    if (rotationY != null && rotationY != _rotationY) {
      _rotationY = rotationY;
      changed = true;
    }
    if (minUserScale != null && minUserScale != _minUserScale) {
      _minUserScale = minUserScale;
      changed = true;
    }
    if (maxUserScale != null && maxUserScale != _maxUserScale) {
      _maxUserScale = maxUserScale;
      changed = true;
    }
    if (userScale != null) {
      final clamped = userScale.clamp(_minUserScale, _maxUserScale).toDouble();
      if (clamped != _userScale) {
        _userScale = clamped;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }
}
