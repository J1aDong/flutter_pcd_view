import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../config/viewer_config.dart';

class NativeRendererBridge {
  NativeRendererBridge._(this.textureId, this._channel);

  static const MethodChannel _methodChannel = MethodChannel(
    'flutter_pcd_view/native_renderer',
  );

  final int textureId;
  final MethodChannel _channel;

  static Future<NativeRendererBridge> create({
    required ViewerConfig config,
  }) async {
    final textureId = await _methodChannel.invokeMethod<int>('createRenderer', {
      'backgroundColor': config.backgroundColor.toARGB32(),
      'pointSize': config.pointSize,
      'zoom': config.camera.zoom,
      'rotationX': config.camera.rotationX,
      'rotationY': config.camera.rotationY,
      'pointBudget': config.performance.nativePointBudget,
      'renderScale': config.performance.nativeRenderScale,
      'gridVisible': config.grid.visible,
      'gridRange': config.grid.range,
      'gridStep': config.grid.step,
      'showAxes': config.showAxes,
    });

    if (textureId == null) {
      throw StateError('Native renderer did not return a textureId');
    }

    return NativeRendererBridge._(
      textureId,
      MethodChannel('flutter_pcd_view/native_renderer/$textureId'),
    );
  }

  Future<void> dispose() => _channel.invokeMethod<void>('dispose');

  Future<void> setViewport({required double width, required double height}) {
    return _channel.invokeMethod<void>('setViewport', {
      'width': width,
      'height': height,
    });
  }

  Future<void> updateConfig(ViewerConfig config) {
    return _channel.invokeMethod<void>('updateConfig', {
      'backgroundColor': config.backgroundColor.toARGB32(),
      'pointSize': config.pointSize,
      'zoom': config.camera.zoom,
      'rotationX': config.camera.rotationX,
      'rotationY': config.camera.rotationY,
      'pointBudget': config.performance.nativePointBudget,
      'renderScale': config.performance.nativeRenderScale,
      'gridVisible': config.grid.visible,
      'gridRange': config.grid.range,
      'gridStep': config.grid.step,
      'showAxes': config.showAxes,
    });
  }

  Future<void> updateCamera({
    required double rotationX,
    required double rotationY,
    required double zoom,
  }) {
    return _channel.invokeMethod<void>('updateCamera', {
      'rotationX': rotationX,
      'rotationY': rotationY,
      'zoom': zoom,
    });
  }

  Future<void> loadPackedScene({
    required Float32List packedPoints,
    required Float32List packedLines,
    required int pointCount,
    required int lineVertexCount,
  }) {
    return _channel.invokeMethod<void>('loadPackedScene', {
      'points': packedPoints.buffer.asUint8List(
        packedPoints.offsetInBytes,
        packedPoints.lengthInBytes,
      ),
      'lines': packedLines.buffer.asUint8List(
        packedLines.offsetInBytes,
        packedLines.lengthInBytes,
      ),
      'pointCount': pointCount,
      'lineVertexCount': lineVertexCount,
    });
  }
}
