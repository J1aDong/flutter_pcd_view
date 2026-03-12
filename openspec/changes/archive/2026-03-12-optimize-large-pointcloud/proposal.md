## Why

Large PCD point cloud files (with millions of points) cause severe performance degradation - laggy interactions, freezing, and unresponsive UI. The current implementation loads all points without any optimization, making it impractical for real-world LiDAR scans which often contain 1M+ points.

## What Changes

- **Point Deduplication**: Remove duplicate/overlapping points during parsing to reduce data size
- **Voxel Grid Downsampling**: Implement industry-standard voxel grid algorithm to intelligently reduce point count while preserving spatial structure
- **Max Points Limit**: Allow users to set maximum point count with automatic downsampling
- **Performance Settings UI**: Add advanced settings panel exposing optimization options to users
- **Progressive Loading**: Support streaming/progressive point cloud loading for better UX

## Capabilities

### New Capabilities

- `pointcloud-optimization`: Core optimization algorithms implemented in Rust including:
  - Duplicate point removal using spatial hashing
  - Voxel grid downsampling with configurable voxel size
  - Maximum point count limiting with intelligent sampling

- `viewer-performance-settings`: Flutter UI components for:
  - Enabling/disabling deduplication
  - Setting max point count
  - Configuring voxel grid size
  - Performance mode toggle

### Modified Capabilities

None - this is a new feature set.

## Impact

- **Rust Layer**: `parser.rs` - add optimization pipeline; `api.rs` - expose new functions
- **FFI Bridge**: Update `flutter_rust_bridge` generated code for new API functions
- **Flutter Config**: `viewer_config.dart` - add performance settings
- **Flutter Widget**: `pcd_view_widget.dart` - integrate optimization settings
- **Example App**: Add settings UI for demonstration
