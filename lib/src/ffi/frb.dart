import 'parser.dart';
import 'frb_generated.dart';
import 'api.dart' as api;

// Re-export generated types
export 'parser.dart' show Point3D;
export 'api.dart' show
    parsePcd,
    parsePcdWithOptimization,
    parsePcdWithProcessing,
    OptimizationOptions,
    ParseResult,
    ProcessingOptions,
    ProcessingResult,
    SOROptions,
    ROROptions,
    ConnectOptions,
    ConnectModeType,
    LineSegmentData;

/// PCD parser interface
class PcdParser {
  static bool _initialized = false;

  /// Initialize the Rust library
  static Future<void> initialize() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  /// Parse PCD file and return list of 3D points
  static Future<List<Point3D>> parsePcd(String path) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      return api.parsePcd(path: path);
    } catch (e) {
      throw Exception('Failed to parse PCD file: $e');
    }
  }

  /// Parse PCD file with optimization options
  static Future<api.ParseResult> parsePcdWithOptimization(
    String path,
    api.OptimizationOptions options,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      return api.parsePcdWithOptimization(path: path, options: options);
    } catch (e) {
      throw Exception('Failed to parse PCD file: $e');
    }
  }
}
