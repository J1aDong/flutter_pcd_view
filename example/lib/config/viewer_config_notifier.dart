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

  // Performance settings
  void updateEnableDeduplication(bool enable) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(enableDeduplication: enable),
    );
    notifyListeners();
  }

  void updateDedupPrecision(double precision) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(dedupPrecision: precision),
    );
    notifyListeners();
  }

  void updateVoxelSize(double size) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(voxelSize: size),
    );
    notifyListeners();
  }

  void updateMaxPoints(int maxPoints) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(maxPoints: maxPoints),
    );
    notifyListeners();
  }

  void resetPerformance() {
    _config = _config.copyWith(
      performance: const PerformanceConfig(),
    );
    notifyListeners();
  }

  // Processing settings - SOR
  void updateSOREnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: enable ? const SORConfig() : null,
      ),
    );
    notifyListeners();
  }

  void updateSORK(int k) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: (_config.processing.sor ?? const SORConfig()).copyWith(k: k),
      ),
    );
    notifyListeners();
  }

  void updateSORStdRatio(double ratio) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: (_config.processing.sor ?? const SORConfig()).copyWith(stdRatio: ratio),
      ),
    );
    notifyListeners();
  }

  // Processing settings - ROR
  void updateROREnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: enable ? const RORConfig() : null,
      ),
    );
    notifyListeners();
  }

  void updateRORRadius(double radius) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: (_config.processing.ror ?? const RORConfig()).copyWith(radius: radius),
      ),
    );
    notifyListeners();
  }

  void updateRORMinNeighbors(int minNeighbors) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: (_config.processing.ror ?? const RORConfig()).copyWith(minNeighbors: minNeighbors),
      ),
    );
    notifyListeners();
  }

  // Processing settings - Connectivity
  void updateConnectMode(ConnectMode mode) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: (_config.processing.connect ?? const ConnectConfig()).copyWith(mode: mode),
      ),
    );
    notifyListeners();
  }

  void updateConnectMaxDistance(double distance) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: (_config.processing.connect ?? const ConnectConfig()).copyWith(maxDistance: distance),
      ),
    );
    notifyListeners();
  }

  void updateConnectEnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: enable ? const ConnectConfig(mode: ConnectMode.sequential) : null,
      ),
    );
    notifyListeners();
  }

  void resetProcessing() {
    _config = _config.copyWith(
      processing: const ProcessingConfig(),
    );
    notifyListeners();
  }
}
