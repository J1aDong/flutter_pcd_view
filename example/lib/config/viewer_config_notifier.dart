import 'package:flutter/material.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

class ViewerConfigNotifier extends ChangeNotifier {
  ViewerConfig _config = const ViewerConfig();

  ViewerConfig get config => _config;

  void updatePointSize(double size) {
    _config = _config.copyWith(pointSize: size);
    notifyListeners();
  }

  void updateBackgroundColor(Color color) {
    _config = _config.copyWith(backgroundColor: color);
    notifyListeners();
  }

  void updateGridVisible(bool visible) {
    _config = _config.copyWith(
      grid: _config.grid.copyWith(visible: visible),
    );
    notifyListeners();
  }

  void updateGridRange(double range) {
    _config = _config.copyWith(
      grid: _config.grid.copyWith(range: range),
    );
    notifyListeners();
  }

  void updateShowAxes(bool show) {
    _config = _config.copyWith(showAxes: show);
    notifyListeners();
  }
}
