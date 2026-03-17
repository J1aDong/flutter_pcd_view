import 'package:flutter/material.dart';
import 'package:flutter_pcd_view/pcd_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewerConfigNotifier extends ChangeNotifier {
  ViewerConfig _config = const ViewerConfig();
  static const _settingsKey = 'viewer_config_v1';

  ViewerConfig get config => _config;

  /// 从持久化存储加载设置
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      _config = _configFromJson(json);
      notifyListeners();
    }
  }

  /// 保存设置到持久化存储
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, _configToJson(_config));
  }

  String _configToJson(ViewerConfig config) {
    // 简化 JSON 序列化：只保存关键配置
    final parts = <String>[
      'ps:${config.pointSize}',
      'bg:${config.backgroundColor.toARGB32()}',
      'ax:${config.showAxes ? 1 : 0}',
      'gv:${config.grid.visible ? 1 : 0}',
      'gr:${config.grid.range}',
      'pd:${config.performance.enableDeduplication ? 1 : 0}',
      'pp:${config.performance.dedupPrecision}',
      'pv:${config.performance.voxelSize}',
      'pm:${config.performance.maxPoints}',
      'np:${config.performance.nativePointBudget}',
      'ns:${config.performance.nativeRenderScale}',
      // Processing settings
      if (config.processing.sor != null) ...[
        'sk:${config.processing.sor!.k}',
        'sr:${config.processing.sor!.stdRatio}',
      ],
      if (config.processing.ror != null) ...[
        'rr:${config.processing.ror!.radius}',
        'rn:${config.processing.ror!.minNeighbors}',
      ],
      if (config.processing.connect != null) ...[
        'cm:${config.processing.connect!.mode.index}',
        'cd:${config.processing.connect!.maxDistance}',
      ],
    ];
    return parts.join(';');
  }

  ViewerConfig _configFromJson(String json) {
    final map = <String, String>{};
    for (final part in json.split(';')) {
      if (part.isEmpty) continue;
      final idx = part.indexOf(':');
      if (idx > 0) {
        map[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }

    SORConfig? sor;
    if (map.containsKey('sk')) {
      sor = SORConfig(
        k: int.tryParse(map['sk'] ?? '50') ?? 50,
        stdRatio: double.tryParse(map['sr'] ?? '2.0') ?? 2.0,
      );
    }

    RORConfig? ror;
    if (map.containsKey('rr')) {
      ror = RORConfig(
        radius: double.tryParse(map['rr'] ?? '0.05') ?? 0.05,
        minNeighbors: int.tryParse(map['rn'] ?? '3') ?? 3,
      );
    }

    ConnectConfig? connect;
    if (map.containsKey('cm')) {
      final modeIndex = int.tryParse(map['cm'] ?? '0') ?? 0;
      final mode = ConnectMode.values[modeIndex.clamp(0, ConnectMode.values.length - 1)];
      connect = ConnectConfig(
        mode: mode,
        maxDistance: double.tryParse(map['cd'] ?? '0.5') ?? 0.5,
      );
    }

    return ViewerConfig(
      pointSize: double.tryParse(map['ps'] ?? '2.0') ?? 2.0,
      backgroundColor: Color(int.tryParse(map['bg'] ?? '4278190080') ?? 4278190080),
      showAxes: (map['ax'] ?? '1') == '1',
      grid: GridConfig(
        visible: (map['gv'] ?? '1') == '1',
        range: double.tryParse(map['gr'] ?? '10.0') ?? 10.0,
      ),
      performance: PerformanceConfig(
        enableDeduplication: (map['pd'] ?? '0') == '1',
        dedupPrecision: double.tryParse(map['pp'] ?? '0.001') ?? 0.001,
        voxelSize: double.tryParse(map['pv'] ?? '0.0') ?? 0.0,
        maxPoints: int.tryParse(map['pm'] ?? '0') ?? 0,
        nativePointBudget: int.tryParse(map['np'] ?? '0') ?? 0,
        nativeRenderScale: double.tryParse(map['ns'] ?? '1.0') ?? 1.0,
      ),
      processing: ProcessingConfig(
        sor: sor,
        ror: ror,
        connect: connect,
      ),
    );
  }

  void updatePointSize(double size) {
    _config = _config.copyWith(pointSize: size);
    saveSettings();
    notifyListeners();
  }

  void updateBackgroundColor(Color color) {
    _config = _config.copyWith(backgroundColor: color);
    saveSettings();
    notifyListeners();
  }

  void updateGridVisible(bool visible) {
    _config = _config.copyWith(
      grid: _config.grid.copyWith(visible: visible),
    );
    saveSettings();
    notifyListeners();
  }

  void updateGridRange(double range) {
    _config = _config.copyWith(
      grid: _config.grid.copyWith(range: range),
    );
    saveSettings();
    notifyListeners();
  }

  void updateShowAxes(bool show) {
    _config = _config.copyWith(showAxes: show);
    saveSettings();
    notifyListeners();
  }

  // Performance settings
  void updateEnableDeduplication(bool enable) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(enableDeduplication: enable),
    );
    saveSettings();
    notifyListeners();
  }

  void updateDedupPrecision(double precision) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(dedupPrecision: precision),
    );
    saveSettings();
    notifyListeners();
  }

  void updateVoxelSize(double size) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(voxelSize: size),
    );
    saveSettings();
    notifyListeners();
  }

  void updateMaxPoints(int maxPoints) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(maxPoints: maxPoints),
    );
    saveSettings();
    notifyListeners();
  }

  void updateNativePointBudget(int budget) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(nativePointBudget: budget),
    );
    saveSettings();
    notifyListeners();
  }

  void updateNativeRenderScale(double scale) {
    _config = _config.copyWith(
      performance: _config.performance.copyWith(nativeRenderScale: scale),
    );
    saveSettings();
    notifyListeners();
  }

  void resetPerformance() {
    _config = _config.copyWith(
      performance: const PerformanceConfig(),
    );
    saveSettings();
    notifyListeners();
  }

  // Processing settings - SOR
  void updateSOREnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: enable ? const SORConfig(k: 30, stdRatio: 2.0) : null,
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateSORK(int k) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: (_config.processing.sor ?? const SORConfig(k: 30, stdRatio: 2.0)).copyWith(k: k),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateSORStdRatio(double ratio) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        sor: (_config.processing.sor ?? const SORConfig(k: 30, stdRatio: 2.0)).copyWith(stdRatio: ratio),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  // Processing settings - ROR
  void updateROREnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: enable ? const RORConfig(radius: 0.05, minNeighbors: 3) : null,
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateRORRadius(double radius) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: (_config.processing.ror ?? const RORConfig(radius: 0.05, minNeighbors: 3)).copyWith(radius: radius),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateRORMinNeighbors(int minNeighbors) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        ror: (_config.processing.ror ?? const RORConfig(radius: 0.05, minNeighbors: 3)).copyWith(minNeighbors: minNeighbors),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  // Processing settings - Connectivity
  void updateConnectMode(ConnectMode mode) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: (_config.processing.connect ?? const ConnectConfig(mode: ConnectMode.sequential)).copyWith(mode: mode),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateConnectMaxDistance(double distance) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: (_config.processing.connect ?? const ConnectConfig(mode: ConnectMode.sequential)).copyWith(maxDistance: distance),
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void updateConnectEnabled(bool enable) {
    _config = _config.copyWith(
      processing: _config.processing.copyWith(
        connect: enable ? const ConnectConfig(mode: ConnectMode.sequential) : null,
      ),
    );
    saveSettings();
    notifyListeners();
  }

  void resetProcessing() {
    _config = _config.copyWith(
      processing: const ProcessingConfig(),
    );
    saveSettings();
    notifyListeners();
  }
}
