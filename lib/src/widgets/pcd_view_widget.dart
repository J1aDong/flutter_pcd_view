import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../config/viewer_config.dart';
import '../ffi/frb.dart' as frb;
import '../native/native_camera_controller.dart';
import '../native/native_renderer_bridge.dart';

class ProcessingStats {
  final int originalCount;
  final int afterSor;
  final int afterRor;
  final int finalCount;
  final int lineCount;

  const ProcessingStats({
    required this.originalCount,
    required this.afterSor,
    required this.afterRor,
    required this.finalCount,
    this.lineCount = 0,
  });

  bool get hasProcessing => originalCount != finalCount;
  double get reductionRatio =>
      originalCount > 0 ? (originalCount - finalCount) / originalCount : 0.0;
}

enum _PcdViewPhase { idle, loading, preparing, ready, error }

class OptimizationStats {
  final int originalCount;
  final int finalCount;

  const OptimizationStats({
    required this.originalCount,
    required this.finalCount,
  });

  bool get hasOptimization => originalCount != finalCount;
  double get reductionRatio =>
      originalCount > 0 ? (originalCount - finalCount) / originalCount : 0.0;
}

class PcdView extends StatefulWidget {
  final List<frb.Point3D>? points;
  final String? filePath;
  final ViewerConfig config;
  final NativeCameraController? controller;
  final void Function(String error)? onError;
  final void Function(int pointCount)? onLoaded;
  final void Function(OptimizationStats stats)? onOptimized;
  final void Function(ProcessingStats stats)? onProcessed;

  const PcdView.fromPoints({
    super.key,
    required this.points,
    this.config = const ViewerConfig(),
    this.controller,
    this.onError,
    this.onLoaded,
    this.onOptimized,
    this.onProcessed,
  }) : filePath = null;

  const PcdView.fromFile({
    super.key,
    required this.filePath,
    this.config = const ViewerConfig(),
    this.controller,
    this.onError,
    this.onLoaded,
    this.onOptimized,
    this.onProcessed,
  }) : points = null;

  @override
  State<PcdView> createState() => _PcdViewState();
}

class _PcdViewState extends State<PcdView> {
  static int _requestSeed = 0;

  late final NativeCameraController _internalController;

  _PcdViewPhase _phase = _PcdViewPhase.idle;
  List<frb.Point3D> _rawPoints = const [];
  List<frb.LineSegmentData> _lineSegments = const [];
  _PackedRenderScene? _nativeScene;
  NativeRendererBridge? _nativeRenderer;
  String? _errorMessage;
  int _activeRequestId = 0;
  double _nativeRotationX = 0;
  double _nativeRotationY = 0;
  double _nativeZoom = 1.0;

  NativeCameraController get _controller => widget.controller ?? _internalController;
  bool get _supportsNativeRenderer => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _internalController = _createController(widget.config);
    _nativeRotationX = _controller.rotationX;
    _nativeRotationY = _controller.rotationY;
    _nativeZoom = _controller.userScale;

    if (_supportsNativeRenderer) {
      unawaited(_startSourceRequest());
    } else {
      _phase = _PcdViewPhase.error;
      _errorMessage = '当前仅支持 Android / iOS 原生渲染';
    }
  }

  @override
  void didUpdateWidget(covariant PcdView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_supportsNativeRenderer) {
      return;
    }

    if (_didSourceChange(oldWidget, widget)) {
      unawaited(_startSourceRequest());
      return;
    }

    if (_didSceneConfigChange(oldWidget.config, widget.config) && _rawPoints.isNotEmpty) {
      unawaited(
        _prepareScene(
          requestId: _activeRequestId,
          points: _rawPoints,
          lines: _lineSegments,
          showPreparingState: false,
          reason: 'config',
          notifyLoaded: false,
        ),
      );
    }

    if (oldWidget.controller == null && widget.controller == null) {
      _internalController.update(
        minUserScale: widget.config.camera.minZoom,
        maxUserScale: widget.config.camera.maxZoom,
      );
    }
  }

  @override
  void dispose() {
    if ((_phase == _PcdViewPhase.loading || _phase == _PcdViewPhase.preparing) &&
        _activeRequestId > 0) {
      _logViewer(
        event: 'cancel_dispose',
        requestId: _activeRequestId,
        fileLabel: _sourceLabel,
        message: 'viewer disposed while request still running',
      );
    }
    _activeRequestId = -1;
    final renderer = _nativeRenderer;
    _nativeRenderer = null;
    if (renderer != null) {
      unawaited(renderer.dispose());
    }
    super.dispose();
  }

  Future<void> _startSourceRequest() async {
    final requestId = ++_requestSeed;
    _activeRequestId = requestId;

    if (widget.filePath == null && widget.points == null) {
      if (!mounted) return;
      setState(() {
        _phase = _PcdViewPhase.idle;
        _rawPoints = const [];
        _lineSegments = const [];
        _nativeScene = null;
        _errorMessage = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _phase = widget.filePath != null ? _PcdViewPhase.loading : _PcdViewPhase.preparing;
        _rawPoints = const [];
        _lineSegments = const [];
        _nativeScene = null;
        _errorMessage = null;
      });
    }

    final parseWatch = Stopwatch()..start();
    final perfConfig = widget.config.performance;
    final procConfig = widget.config.processing;

    try {
      late final List<frb.Point3D> points;
      late final List<frb.LineSegmentData> lines;
      int? originalCount;
      int? finalCount;
      int? afterSor;
      int? afterRor;

      if (widget.points != null) {
        points = List<frb.Point3D>.from(widget.points!);
        lines = const [];
        parseWatch.stop();
        _logViewer(
          event: 'parse_skipped',
          requestId: requestId,
          fileLabel: _sourceLabel,
          elapsed: parseWatch.elapsed,
          pointCount: points.length,
          message: 'using in-memory points',
        );
      } else {
        _logViewer(
          event: 'parse_start',
          requestId: requestId,
          fileLabel: _sourceLabel,
          optimization: perfConfig.isEnabled,
          processing: procConfig.isEnabled,
        );

        if (perfConfig.isEnabled || procConfig.isEnabled) {
          final optOptions = frb.OptimizationOptions(
            enableDeduplication: perfConfig.enableDeduplication,
            dedupPrecision: perfConfig.dedupPrecision,
            voxelSize: perfConfig.voxelSize,
            maxPoints: perfConfig.maxPoints,
          );

          final procOptions = _buildProcessingOptions(procConfig);

          final result = await frb.parsePcdWithProcessing(
            path: widget.filePath!,
            optOptions: optOptions,
            procOptions: procOptions,
          );
          points = result.points;
          lines = result.lineSegments;
          originalCount = result.originalCount;
          afterSor = result.afterSor;
          afterRor = result.afterRor;
          finalCount = result.finalCount;
        } else {
          points = await frb.PcdParser.parsePcd(widget.filePath!);
          lines = const [];
        }

        parseWatch.stop();
        _logViewer(
          event: 'parse_done',
          requestId: requestId,
          fileLabel: _sourceLabel,
          elapsed: parseWatch.elapsed,
          pointCount: points.length,
          originalCount: originalCount,
          optimization: perfConfig.isEnabled,
          processing: procConfig.isEnabled,
        );
      }

      if (!_isCurrentRequest(requestId)) {
        _logViewer(
          event: 'parse_stale',
          requestId: requestId,
          fileLabel: _sourceLabel,
          pointCount: points.length,
          message: 'parsed result ignored because a newer request exists',
        );
        return;
      }

      if (originalCount != null && finalCount != null && widget.onOptimized != null) {
        widget.onOptimized!.call(
          OptimizationStats(
            originalCount: originalCount,
            finalCount: finalCount,
          ),
        );
      }

      if (afterSor != null && afterRor != null && widget.onProcessed != null) {
        widget.onProcessed!.call(
          ProcessingStats(
            originalCount: originalCount ?? 0,
            afterSor: afterSor,
            afterRor: afterRor,
            finalCount: finalCount ?? 0,
            lineCount: lines.length,
          ),
        );
      }

      await _prepareScene(
        requestId: requestId,
        points: points,
        lines: lines,
        showPreparingState: true,
        reason: 'source',
        notifyLoaded: true,
      );
    } catch (error, stackTrace) {
      parseWatch.stop();
      if (!_isCurrentRequest(requestId)) {
        _logViewer(
          event: 'parse_stale_error',
          requestId: requestId,
          fileLabel: _sourceLabel,
          elapsed: parseWatch.elapsed,
          message: 'stale error ignored: $error',
        );
        return;
      }

      _logViewer(
        event: 'parse_error',
        requestId: requestId,
        fileLabel: _sourceLabel,
        elapsed: parseWatch.elapsed,
        message: error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;
      setState(() {
        _phase = _PcdViewPhase.error;
        _errorMessage = error.toString();
      });
      widget.onError?.call(error.toString());
    }
  }

  Future<void> _prepareScene({
    required int requestId,
    required List<frb.Point3D> points,
    required List<frb.LineSegmentData> lines,
    required bool showPreparingState,
    required String reason,
    required bool notifyLoaded,
  }) async {
    if (showPreparingState && mounted) {
      setState(() {
        _phase = _PcdViewPhase.preparing;
      });
    }

    _logViewer(
      event: 'prepare_start',
      requestId: requestId,
      fileLabel: _sourceLabel,
      pointCount: points.length,
      lineCount: lines.length,
      message: 'reason=$reason',
    );

    await Future<void>.delayed(Duration.zero);

    final prepareWatch = Stopwatch()..start();
    _logViewer(
      event: 'native_renderer_prepare',
      requestId: requestId,
      fileLabel: _sourceLabel,
      pointCount: points.length,
      lineCount: lines.length,
      message: 'before ensure renderer',
    );
    final scene = _buildPackedScene(points, lines, widget.config);
    await _ensureNativeRenderer();
    _logViewer(
      event: 'native_renderer_prepare',
      requestId: requestId,
      fileLabel: _sourceLabel,
      pointCount: scene.pointCount,
      lineCount: scene.lineVertexCount,
      message: 'renderer ready, upload scene',
    );
    await _nativeRenderer!.updateConfig(widget.config);
    await _nativeRenderer!.loadPackedScene(
      packedPoints: scene.packedPoints,
      packedLines: scene.packedLines,
      pointCount: scene.pointCount,
      lineVertexCount: scene.lineVertexCount,
    );
    _logViewer(
      event: 'native_renderer_prepare',
      requestId: requestId,
      fileLabel: _sourceLabel,
      pointCount: scene.pointCount,
      lineCount: scene.lineVertexCount,
      message: 'scene uploaded, update camera',
    );
    await _nativeRenderer!.updateCamera(
      rotationX: _nativeRotationX,
      rotationY: _nativeRotationY,
      zoom: _nativeZoom,
    );
    prepareWatch.stop();

    if (!_isCurrentRequest(requestId)) {
      _logViewer(
        event: 'prepare_stale',
        requestId: requestId,
        fileLabel: _sourceLabel,
        elapsed: prepareWatch.elapsed,
        pointCount: points.length,
        message: 'prepared scene ignored because a newer request exists',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _rawPoints = points;
      _lineSegments = lines;
      _nativeScene = scene;
      _phase = _PcdViewPhase.ready;
      _errorMessage = null;
    });

    _logViewer(
      event: 'prepare_done',
      requestId: requestId,
      fileLabel: _sourceLabel,
      elapsed: prepareWatch.elapsed,
      pointCount: points.length,
      lineCount: lines.length,
      message: 'reason=$reason',
    );

    if (notifyLoaded) {
      _logViewer(
        event: 'native_renderer_prepare',
        requestId: requestId,
        fileLabel: _sourceLabel,
        pointCount: points.length,
        lineCount: lines.length,
        message: 'setState ready complete',
      );
      widget.onLoaded?.call(points.length);
    }
  }

  Future<void> _ensureNativeRenderer() async {
    if (_nativeRenderer != null) return;
    _nativeRenderer = await NativeRendererBridge.create(config: widget.config);
  }

  Future<void> _handleNativeViewport(Size size) async {
    final renderer = _nativeRenderer;
    if (renderer == null) return;
    await renderer.setViewport(width: size.width, height: size.height);
  }

  Future<void> _handleNativeCameraUpdate({
    required double rotationX,
    required double rotationY,
    required double zoom,
  }) async {
    _nativeRotationX = rotationX;
    _nativeRotationY = rotationY;
    _nativeZoom = zoom
        .clamp(widget.config.camera.minZoom, widget.config.camera.maxZoom)
        .toDouble();
    _controller.update(
      rotationX: _nativeRotationX,
      rotationY: _nativeRotationY,
      userScale: _nativeZoom,
    );
    final renderer = _nativeRenderer;
    if (renderer != null) {
      await renderer.updateCamera(
        rotationX: _nativeRotationX,
        rotationY: _nativeRotationY,
        zoom: _nativeZoom,
      );
    }
  }

  frb.ProcessingOptions _buildProcessingOptions(ProcessingConfig config) {
    return frb.ProcessingOptions(
      sor: config.sor != null
          ? frb.SOROptions(k: config.sor!.k, stdRatio: config.sor!.stdRatio)
          : null,
      ror: config.ror != null
          ? frb.ROROptions(
              radius: config.ror!.radius,
              minNeighbors: config.ror!.minNeighbors,
            )
          : null,
      connect: config.connect != null && config.connect!.isEnabled
          ? frb.ConnectOptions(
              mode: _toConnectModeType(config.connect!.mode),
              maxDistance: config.connect!.maxDistance,
              maxSegments: config.connect!.maxSegments,
            )
          : null,
    );
  }

  frb.ConnectModeType _toConnectModeType(ConnectMode mode) {
    switch (mode) {
      case ConnectMode.none:
        return frb.ConnectModeType.none;
      case ConnectMode.sequential:
        return frb.ConnectModeType.sequential;
      case ConnectMode.nearestNeighbor:
        return frb.ConnectModeType.nearestNeighbor;
    }
  }

  _PackedRenderScene _buildPackedScene(
    List<frb.Point3D> points,
    List<frb.LineSegmentData> lines,
    ViewerConfig config,
  ) {
    final pointVertices = <_PackedVertex>[];
    final lineVertices = <_PackedVertex>[];
    final bounds = _SceneBounds();

    for (final point in points) {
      bounds.expand(point.x, point.y, point.z);
      pointVertices.add(
        _PackedVertex(
          x: point.x,
          y: point.y,
          z: point.z,
          color: Color(point.color),
        ),
      );
    }

    if (config.grid.visible) {
      final range = config.grid.range;
      final step = config.grid.step;
      for (double y = -range; y <= range; y += step) {
        _appendLine(lineVertices, bounds, -range, y, 0, range, y, 0, config.grid.color);
      }
      for (double x = -range; x <= range; x += step) {
        _appendLine(lineVertices, bounds, x, -range, 0, x, range, 0, config.grid.color);
      }
    }

    if (config.showAxes) {
      final axisRange = config.grid.range / 2;
      _appendLine(lineVertices, bounds, 0, 0, 0, axisRange, 0, 0, Colors.red);
      _appendLine(lineVertices, bounds, 0, 0, 0, 0, axisRange, 0, Colors.green);
      _appendLine(lineVertices, bounds, 0, 0, 0, 0, 0, axisRange, Colors.blue);
    }

    for (final line in lines) {
      _appendLine(
        lineVertices,
        bounds,
        line.start.x,
        line.start.y,
        line.start.z,
        line.end.x,
        line.end.y,
        line.end.z,
        const Color(0xFF00FF00),
      );
    }

    final normalizer = bounds.normalizer;
    final packedPoints = Float32List(pointVertices.length * 7);
    for (var i = 0; i < pointVertices.length; i++) {
      final base = i * 7;
      _writePackedVertex(packedPoints, base, pointVertices[i], normalizer);
    }

    final packedLines = Float32List(lineVertices.length * 7);
    for (var i = 0; i < lineVertices.length; i++) {
      final base = i * 7;
      _writePackedVertex(packedLines, base, lineVertices[i], normalizer);
    }

    return _PackedRenderScene(
      packedPoints: packedPoints,
      packedLines: packedLines,
      pointCount: pointVertices.length,
      lineVertexCount: lineVertices.length,
    );
  }

  NativeCameraController _createController(ViewerConfig config) {
    return NativeCameraController(
      rotationX: config.camera.rotationX,
      rotationY: config.camera.rotationY,
      userScale: config.camera.zoom,
      minUserScale: config.camera.minZoom,
      maxUserScale: config.camera.maxZoom,
    );
  }

  bool _isCurrentRequest(int requestId) {
    return mounted && requestId == _activeRequestId;
  }

  String get _sourceLabel {
    final path = widget.filePath;
    if (path == null || path.isEmpty) {
      return 'memory';
    }

    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : path;
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _PcdViewPhase.loading:
      case _PcdViewPhase.preparing:
        return Container(color: widget.config.backgroundColor);
      case _PcdViewPhase.error:
        return _StatusView(
          backgroundColor: widget.config.backgroundColor,
          title: '加载失败',
          subtitle: _errorMessage ?? '未知错误',
          loading: false,
          foregroundColor: Colors.redAccent,
        );
      case _PcdViewPhase.ready:
        if (_nativeRenderer == null || _nativeScene == null) {
          return _StatusView(
            backgroundColor: widget.config.backgroundColor,
            title: '没有点云数据',
            subtitle: _sourceLabel,
            loading: false,
          );
        }
        return _NativePcdTextureRenderer(
          textureId: _nativeRenderer!.textureId,
          backgroundColor: widget.config.backgroundColor,
          rotationX: _nativeRotationX,
          rotationY: _nativeRotationY,
          zoom: _nativeZoom,
          onViewportChanged: _handleNativeViewport,
          onCameraChanged: _handleNativeCameraUpdate,
        );
      case _PcdViewPhase.idle:
        return _StatusView(
          backgroundColor: widget.config.backgroundColor,
          title: '没有点云数据',
          subtitle: '请选择一个 PCD 文件',
          loading: false,
        );
    }
  }
}

class _NativePcdTextureRenderer extends StatefulWidget {
  final int textureId;
  final Color backgroundColor;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final Future<void> Function(Size size) onViewportChanged;
  final Future<void> Function({
    required double rotationX,
    required double rotationY,
    required double zoom,
  }) onCameraChanged;

  const _NativePcdTextureRenderer({
    required this.textureId,
    required this.backgroundColor,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.onViewportChanged,
    required this.onCameraChanged,
  });

  @override
  State<_NativePcdTextureRenderer> createState() => _NativePcdTextureRendererState();
}

class _NativePcdTextureRendererState extends State<_NativePcdTextureRenderer> {
  double _lastX = 0;
  double _lastY = 0;
  double _scaleBase = 1.0;
  double _rotationX = 0;
  double _rotationY = 0;
  double _zoom = 1.0;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rotationX = widget.rotationX;
    _rotationY = widget.rotationY;
    _zoom = widget.zoom;
  }

  @override
  void didUpdateWidget(covariant _NativePcdTextureRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationX != widget.rotationX ||
        oldWidget.rotationY != widget.rotationY ||
        oldWidget.zoom != widget.zoom) {
      _rotationX = widget.rotationX;
      _rotationY = widget.rotationY;
      _zoom = widget.zoom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size.width > 0 && size.height > 0 && size != _lastSize) {
            _lastSize = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _logViewer(
                event: 'texture_viewport_request',
                requestId: 0,
                fileLabel: 'native_texture',
                message: 'size=${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}',
              );
              unawaited(widget.onViewportChanged(size));
            });
          }

          return Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final nextZoom = (_zoom - pointerSignal.scrollDelta.dy / 200)
                    .clamp(0.1, 10.0)
                    .toDouble();
                _zoom = nextZoom;
                unawaited(
                  widget.onCameraChanged(
                    rotationX: _rotationX,
                    rotationY: _rotationY,
                    zoom: _zoom,
                  ),
                );
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _scaleBase = _zoom;
                _lastX = details.localFocalPoint.dx;
                _lastY = details.localFocalPoint.dy;
              },
              onScaleUpdate: (details) {
                final dx = details.localFocalPoint.dx - _lastX;
                final dy = details.localFocalPoint.dy - _lastY;
                _lastX = details.localFocalPoint.dx;
                _lastY = details.localFocalPoint.dy;

                if (details.pointerCount > 1) {
                  _zoom = (_scaleBase * details.scale).clamp(0.1, 10.0).toDouble();
                } else {
                  _rotationX = _rotationX + dy / 16;
                  _rotationY = _rotationY + dx / 16;
                }

                unawaited(
                  widget.onCameraChanged(
                    rotationX: _rotationX,
                    rotationY: _rotationY,
                    zoom: _zoom,
                  ),
                );
              },
              child: Texture(textureId: widget.textureId),
            ),
          );
        },
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final bool loading;
  final Color foregroundColor;

  const _StatusView({
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    this.foregroundColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(),
                )
              else
                Icon(
                  Icons.info_outline,
                  size: 36,
                  color: foregroundColor,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: foregroundColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackedRenderScene {
  final Float32List packedPoints;
  final Float32List packedLines;
  final int pointCount;
  final int lineVertexCount;

  const _PackedRenderScene({
    required this.packedPoints,
    required this.packedLines,
    required this.pointCount,
    required this.lineVertexCount,
  });
}

class _PackedVertex {
  final double x;
  final double y;
  final double z;
  final Color color;

  const _PackedVertex({
    required this.x,
    required this.y,
    required this.z,
    required this.color,
  });
}

class _SceneBounds {
  double minX = double.infinity;
  double minY = double.infinity;
  double minZ = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;
  double maxZ = double.negativeInfinity;

  void expand(double x, double y, double z) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
    if (z < minZ) minZ = z;
    if (z > maxZ) maxZ = z;
  }

  _SceneNormalizer get normalizer {
    if (!minX.isFinite) {
      return const _SceneNormalizer(centerX: 0, centerY: 0, centerZ: 0, scale: 1);
    }
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final centerZ = (minZ + maxZ) / 2;
    final extentX = maxX - minX;
    final extentY = maxY - minY;
    final extentZ = maxZ - minZ;
    final maxExtent = [extentX, extentY, extentZ].reduce((a, b) => a > b ? a : b);
    final scale = maxExtent <= 0 ? 1.0 : maxExtent / 2;
    return _SceneNormalizer(
      centerX: centerX,
      centerY: centerY,
      centerZ: centerZ,
      scale: scale,
    );
  }
}

class _SceneNormalizer {
  final double centerX;
  final double centerY;
  final double centerZ;
  final double scale;

  const _SceneNormalizer({
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.scale,
  });
}

void _appendLine(
  List<_PackedVertex> vertices,
  _SceneBounds bounds,
  double startX,
  double startY,
  double startZ,
  double endX,
  double endY,
  double endZ,
  Color color,
) {
  bounds.expand(startX, startY, startZ);
  bounds.expand(endX, endY, endZ);
  vertices.add(_PackedVertex(x: startX, y: startY, z: startZ, color: color));
  vertices.add(_PackedVertex(x: endX, y: endY, z: endZ, color: color));
}

void _writePackedVertex(
  Float32List target,
  int offset,
  _PackedVertex vertex,
  _SceneNormalizer normalizer,
) {
  target[offset] = (vertex.x - normalizer.centerX) / normalizer.scale;
  target[offset + 1] = (vertex.y - normalizer.centerY) / normalizer.scale;
  target[offset + 2] = (vertex.z - normalizer.centerZ) / normalizer.scale;
  target[offset + 3] = vertex.color.r;
  target[offset + 4] = vertex.color.g;
  target[offset + 5] = vertex.color.b;
  target[offset + 6] = vertex.color.a * 0.8;
}

bool _didSourceChange(PcdView oldWidget, PcdView newWidget) {
  return oldWidget.filePath != newWidget.filePath ||
      !identical(oldWidget.points, newWidget.points);
}

bool _didSceneConfigChange(ViewerConfig oldConfig, ViewerConfig newConfig) {
  return oldConfig.pointSize != newConfig.pointSize ||
      oldConfig.backgroundColor != newConfig.backgroundColor ||
      oldConfig.showAxes != newConfig.showAxes ||
      oldConfig.grid.visible != newConfig.grid.visible ||
      oldConfig.grid.range != newConfig.grid.range ||
      oldConfig.grid.step != newConfig.grid.step ||
      oldConfig.grid.color != newConfig.grid.color ||
      oldConfig.camera.zoom != newConfig.camera.zoom ||
      oldConfig.camera.rotationX != newConfig.camera.rotationX ||
      oldConfig.camera.rotationY != newConfig.camera.rotationY;
}

void _logViewer({
  required String event,
  required int requestId,
  required String fileLabel,
  Duration? elapsed,
  int? pointCount,
  int? lineCount,
  int? originalCount,
  bool? optimization,
  bool? processing,
  String? message,
  Object? error,
  StackTrace? stackTrace,
}) {
  final parts = <String>[
    'event=$event',
    'requestId=$requestId',
    'file=$fileLabel',
    if (pointCount != null) 'points=$pointCount',
    if (lineCount != null) 'lines=$lineCount',
    if (originalCount != null) 'original=$originalCount',
    if (optimization != null) 'optimization=$optimization',
    if (processing != null) 'processing=$processing',
    if (elapsed != null) 'elapsedMs=${elapsed.inMilliseconds}',
    if (message != null && message.isNotEmpty) 'message=$message',
  ];

  developer.log(
    parts.join(' '),
    name: 'flutter_pcd_view.viewer',
    error: error,
    stackTrace: stackTrace,
  );
}
