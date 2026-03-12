import 'package:flutter/material.dart';
import 'ffi/api.dart';
import 'ffi/parser.dart';

class PcdViewer extends StatefulWidget {
  final String pcdData;
  final double width;
  final double height;

  const PcdViewer({
    super.key,
    required this.pcdData,
    this.width = 300,
    this.height = 300,
  });

  @override
  State<PcdViewer> createState() => _PcdViewerState();
}

class _PcdViewerState extends State<PcdViewer> {
  List<Point3D>? _points;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parsePcdData();
  }

  @override
  void didUpdateWidget(PcdViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pcdData != widget.pcdData) {
      _parsePcdData();
    }
  }

  Future<void> _parsePcdData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final points = await parsePcdData(content: widget.pcdData);
      if (!mounted) return;
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '解析错误:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_points == null || _points!.isEmpty) {
      return const Center(
        child: Text('没有点云数据'),
      );
    }

    return CustomPaint(
      painter: _PointCloudPainter(_points!),
      child: Center(
        child: Text(
          '${_points!.length} 个点',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _PointCloudPainter extends CustomPainter {
  final List<Point3D> points;

  _PointCloudPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 计算点云边界
    double minX = points[0].x, maxX = points[0].x;
    double minY = points[0].y, maxY = points[0].y;
    double minZ = points[0].z, maxZ = points[0].z;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
      if (point.z < minZ) minZ = point.z;
      if (point.z > maxZ) maxZ = point.z;
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final rangeZ = maxZ - minZ;
    final maxRange = [rangeX, rangeY, rangeZ].reduce((a, b) => a > b ? a : b);

    if (maxRange == 0) return;

    // 绘制点云（简单的 2D 投影）
    final padding = 20.0;
    final scale = (size.width - padding * 2) / maxRange;

    for (final point in points) {
      final x = (point.x - minX) * scale + padding;
      final y = size.height - ((point.y - minY) * scale + padding);

      final paint = Paint()
        ..color = Color(point.color)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_PointCloudPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
