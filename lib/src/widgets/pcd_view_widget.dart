import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../config/viewer_config.dart';
import '../ffi/api.dart';
import '../models/point_3d_adapter.dart';

/// PCD 点云查看器 Widget
///
/// 支持从文件路径或预解析数据加载点云，提供交互式 3D 查看
class PcdView extends HookWidget {
  /// 点云数据（预解析）
  final List<dynamic>? points;

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

  const PcdView.fromPoints({
    super.key,
    required this.points,
    this.config = const ViewerConfig(),
    this.controller,
    this.onError,
    this.onLoaded,
  }) : filePath = null;

  const PcdView.fromFile({
    super.key,
    required this.filePath,
    this.config = const ViewerConfig(),
    this.controller,
    this.onError,
    this.onLoaded,
  }) : points = null;

  @override
  Widget build(BuildContext context) {
    final loadedPoints = useState<List<dynamic>?>(points);
    final error = useState<String?>(null);
    final isLoading = useState(points == null && filePath != null);

    useEffect(() {
      if (filePath != null && points == null) {
        isLoading.value = true;
        error.value = null;

        try {
          final parsed = parsePcd(path: filePath!);
          loadedPoints.value = parsed;
          isLoading.value = false;
          onLoaded?.call(parsed.length);
        } catch (e) {
          error.value = e.toString();
          isLoading.value = false;
          onError?.call(e.toString());
        }
      } else if (points != null) {
        loadedPoints.value = points;
        onLoaded?.call(points!.length);
      }
      return null;
    }, [filePath, points]);

    if (isLoading.value) {
      return Container(
        color: config.backgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error.value != null) {
      return Container(
        color: config.backgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '加载失败:\n${error.value}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (loadedPoints.value == null || loadedPoints.value!.isEmpty) {
      return Container(
        color: config.backgroundColor,
        child: const Center(
          child: Text(
            '没有点云数据',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return _PcdViewRenderer(
      points: loadedPoints.value!,
      config: config,
      controller: controller,
    );
  }
}

class _PcdViewRenderer extends HookWidget {
  final List<dynamic> points;
  final ViewerConfig config;
  final DiTreDiController? controller;

  const _PcdViewRenderer({
    required this.points,
    required this.config,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final ditrediController = controller ??
        useMemoized(
          () => DiTreDiController(
            rotationX: config.camera.rotationX,
            rotationY: config.camera.rotationY,
            userScale: config.camera.zoom,
            minUserScale: config.camera.minZoom,
            maxUserScale: config.camera.maxZoom,
          ),
        );

    final ditrediPoints = useMemoized(
      () => Point3DAdapter.ffiToDitrediList(
        points.cast(),
        pointSize: config.pointSize,
      ),
      [points, config.pointSize],
    );

    final figures = useMemoized(() {
      final list = <Model3D<Model3D<dynamic>>>[];

      // 添加网格
      if (config.grid.visible) {
        final gridLines = <Line3D>[];
        final range = config.grid.range;
        final step = config.grid.step;

        // X 方向网格线
        for (double y = -range; y <= range; y += step) {
          gridLines.add(Line3D(
            Vector3(-range, y, 0),
            Vector3(range, y, 0),
            width: 1,
            color: config.grid.color,
          ));
        }

        // Y 方向网格线
        for (double x = -range; x <= range; x += step) {
          gridLines.add(Line3D(
            Vector3(x, -range, 0),
            Vector3(x, range, 0),
            width: 1,
            color: config.grid.color,
          ));
        }

        list.add(Group3D(gridLines));
      }

      // 添加坐标轴
      if (config.showAxes) {
        list.add(
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

      // 添加点云
      list.add(Group3D(ditrediPoints));

      return list;
    }, [ditrediPoints, config.grid, config.showAxes]);

    return Container(
      color: config.backgroundColor,
      child: DiTreDi(
        controller: ditrediController,
        figures: figures,
      ),
    );
  }
}
