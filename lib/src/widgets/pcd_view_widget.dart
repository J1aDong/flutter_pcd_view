import 'dart:async';
import 'dart:developer' as developer;

import 'package:ditredi/ditredi.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../config/viewer_config.dart';
import '../ffi/frb.dart' as frb;
import '../models/point_3d_adapter.dart';

/// 处理结果统计
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

/// 优化结果统计
class OptimizationStats {
  /// 原始点数
  final int originalCount;

  /// 优化后点数
  final int finalCount;

  const OptimizationStats({
    required this.originalCount,
    required this.finalCount,
  });

  /// 是否有优化
  bool get hasOptimization => originalCount != finalCount;

  /// 减少比例
  double get reductionRatio =>
      originalCount > 0 ? (originalCount - finalCount) / originalCount : 0.0;
}

/// PCD 点云查看器 Widget
///
/// 支持从文件路径或预解析数据加载点云，提供交互式 3D 查看
class PcdView extends StatefulWidget {
  /// 点云数据（预解析）
  final List<frb.Point3D>? points;

  /// PCD 文件路径
  final String? filePath;

  /// 查看器配置
  final ViewerConfig config;

  /// 自定义 DiTreDi 控制器
  final DiTreDiController? controller;

  /// 加载错误回调
  final void Function(String error)? onError;

  /// 加载完成回调
  final void Function(int pointCount)? onLoaded;

  /// 优化完成回调（仅当启用优化时触发）
  final void Function(OptimizationStats stats)? onOptimized;

  /// 处理完成回调（仅当启用处理时触发）
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

  late final DiTreDiController _internalController;

  _PcdViewPhase _phase = _PcdViewPhase.idle;
  List<frb.Point3D> _rawPoints = const [];
  List<frb.LineSegmentData> _lineSegments = const [];
  List<Model3D> _figures = const [];
  String? _errorMessage;
  int _activeRequestId = 0;

  DiTreDiController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = _createController(widget.config);
    unawaited(_startSourceRequest());
  }

  @override
  void didUpdateWidget(covariant PcdView oldWidget) {
    super.didUpdateWidget(oldWidget);

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
    if ((_phase == _PcdViewPhase.loading || _phase == _PcdViewPhase.preparing) && _activeRequestId > 0) {
      _logViewer(
        event: 'cancel_dispose',
        requestId: _activeRequestId,
        fileLabel: _sourceLabel,
        message: 'viewer disposed while request still running',
      );
    }
    _activeRequestId = -1;
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
        _figures = const [];
        _errorMessage = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _phase = widget.filePath != null ? _PcdViewPhase.loading : _PcdViewPhase.preparing;
        _rawPoints = const [];
        _figures = const [];
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

      // Notify optimization stats
      if (originalCount != null && finalCount != null && widget.onOptimized != null) {
        widget.onOptimized!.call(OptimizationStats(
          originalCount: originalCount,
          finalCount: finalCount,
        ));
      }

      // Notify processing stats
      if (afterSor != null && afterRor != null && widget.onProcessed != null) {
        widget.onProcessed!.call(ProcessingStats(
          originalCount: originalCount ?? 0,
          afterSor: afterSor,
          afterRor: afterRor,
          finalCount: finalCount ?? 0,
          lineCount: lines.length,
        ));
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
    final figures = _buildFigures(points, lines, widget.config);
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
      _figures = figures;
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
      widget.onLoaded?.call(points.length);
    }
  }

  frb.ProcessingOptions _buildProcessingOptions(ProcessingConfig config) {
    return frb.ProcessingOptions(
      sor: config.sor != null
          ? frb.SOROptions(k: config.sor!.k, stdRatio: config.sor!.stdRatio)
          : null,
      ror: config.ror != null
          ? frb.ROROptions(radius: config.ror!.radius, minNeighbors: config.ror!.minNeighbors)
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

  List<Model3D> _buildFigures(List<frb.Point3D> points, List<frb.LineSegmentData> lines, ViewerConfig config) {
    final figures = <Model3D>[];

    if (config.grid.visible) {
      final gridLines = <Line3D>[];
      final range = config.grid.range;
      final step = config.grid.step;

      for (double y = -range; y <= range; y += step) {
        gridLines.add(
          Line3D(
            Vector3(-range, y, 0),
            Vector3(range, y, 0),
            width: 1,
            color: config.grid.color,
          ),
        );
      }

      for (double x = -range; x <= range; x += step) {
        gridLines.add(
          Line3D(
            Vector3(x, -range, 0),
            Vector3(x, range, 0),
            width: 1,
            color: config.grid.color,
          ),
        );
      }

      figures.add(Group3D(gridLines));
    }

    if (config.showAxes) {
      figures.add(
        Group3D([
          Line3D(
            Vector3.zero(),
            Vector3(config.grid.range / 2, 0, 0),
            width: 2,
            color: Colors.red,
          ),
          Line3D(
            Vector3.zero(),
            Vector3(0, config.grid.range / 2, 0),
            width: 2,
            color: Colors.green,
          ),
          Line3D(
            Vector3.zero(),
            Vector3(0, 0, config.grid.range / 2),
            width: 2,
            color: Colors.blue,
          ),
        ]),
      );
    }

    // Render line segments from connectivity
    if (lines.isNotEmpty) {
      final lineFigures = lines.map((line) => Line3D(
        Vector3(line.start.x, line.start.y, line.start.z),
        Vector3(line.end.x, line.end.y, line.end.z),
        width: 1,
        color: const Color(0xFF00FF00), // Green lines
      )).toList();
      figures.add(Group3D(lineFigures));
    }

    figures.add(
      Group3D(
        Point3DAdapter.ffiToDitrediList(
          points,
          pointSize: config.pointSize,
        ),
      ),
    );

    return figures;
  }

  DiTreDiController _createController(ViewerConfig config) {
    return DiTreDiController(
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
        return _StatusView(
          backgroundColor: widget.config.backgroundColor,
          title: '正在解析点云文件',
          subtitle: _sourceLabel,
          loading: true,
        );
      case _PcdViewPhase.preparing:
        return _StatusView(
          backgroundColor: widget.config.backgroundColor,
          title: '正在准备渲染场景',
          subtitle: _sourceLabel,
          loading: true,
        );
      case _PcdViewPhase.error:
        return _StatusView(
          backgroundColor: widget.config.backgroundColor,
          title: '加载失败',
          subtitle: _errorMessage ?? '未知错误',
          loading: false,
          foregroundColor: Colors.redAccent,
        );
      case _PcdViewPhase.ready:
        if (_figures.isEmpty) {
          return _StatusView(
            backgroundColor: widget.config.backgroundColor,
            title: '没有点云数据',
            subtitle: _sourceLabel,
            loading: false,
          );
        }
        return _PcdViewRenderer(
          controller: _controller,
          figures: _figures,
          backgroundColor: widget.config.backgroundColor,
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

class _PcdViewRenderer extends StatefulWidget {
  final DiTreDiController controller;
  final List<Model3D> figures;
  final Color backgroundColor;

  const _PcdViewRenderer({
    required this.controller,
    required this.figures,
    required this.backgroundColor,
  });

  @override
  State<_PcdViewRenderer> createState() => _PcdViewRendererState();
}

class _PcdViewRendererState extends State<_PcdViewRenderer> {
  double _lastX = 0;
  double _lastY = 0;
  double _scaleBase = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final viewScale = widget.controller.viewScale == 0 ? 1.0 : widget.controller.viewScale;
            final scaledDy = pointerSignal.scrollDelta.dy / viewScale;
            widget.controller.update(
              userScale: widget.controller.userScale - scaledDy,
            );
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _scaleBase = widget.controller.userScale;
            _lastX = details.localFocalPoint.dx;
            _lastY = details.localFocalPoint.dy;
          },
          onScaleUpdate: (details) {
            final dx = details.localFocalPoint.dx - _lastX;
            final dy = details.localFocalPoint.dy - _lastY;

            _lastX = details.localFocalPoint.dx;
            _lastY = details.localFocalPoint.dy;

            widget.controller.update(
              userScale: _scaleBase * details.scale,
              rotationX: widget.controller.rotationX - dy / 2,
              rotationY: ((widget.controller.rotationY - dx / 2 + 360) % 360).clamp(0, 360),
            );
          },
          child: DiTreDi(
            controller: widget.controller,
            figures: widget.figures,
          ),
        ),
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

bool _didSourceChange(PcdView oldWidget, PcdView newWidget) {
  return oldWidget.filePath != newWidget.filePath || !identical(oldWidget.points, newWidget.points);
}

bool _didSceneConfigChange(ViewerConfig oldConfig, ViewerConfig newConfig) {
  return oldConfig.pointSize != newConfig.pointSize ||
      oldConfig.showAxes != newConfig.showAxes ||
      oldConfig.grid.visible != newConfig.grid.visible ||
      oldConfig.grid.range != newConfig.grid.range ||
      oldConfig.grid.step != newConfig.grid.step ||
      oldConfig.grid.color != newConfig.grid.color;
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
