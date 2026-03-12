import 'package:flutter/material.dart';

class PcdViewer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'PCD Viewer\n${pcdData.length} bytes',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
