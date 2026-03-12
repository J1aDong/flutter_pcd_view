## 1. Rust Core Implementation

- [x] 1.1 Add deduplication module in Rust (`rust/src/optimization/dedup.rs`)
- [x] 1.2 Implement spatial hashing for O(n) deduplication
- [x] 1.3 Add voxel grid downsampling module (`rust/src/optimization/voxel_grid.rs`)
- [x] 1.4 Implement voxel grid centroid calculation with color averaging
- [x] 1.5 Add max points limiting with uniform sampling fallback
- [x] 1.6 Create optimization pipeline struct with configurable options
- [x] 1.7 Add unit tests for each optimization function

## 2. FFI Bridge Updates

- [x] 2.1 Define OptimizationConfig struct in Rust API
- [x] 2.2 Update parse_pcd API to accept optional optimization config
- [x] 2.3 Run flutter_rust_bridge code generation
- [x] 2.4 Verify generated Dart bindings compile correctly

## 3. Flutter Configuration

- [x] 3.1 Add PerformanceConfig class to `lib/src/config/viewer_config.dart`
- [x] 3.2 Add fields: enableDeduplication, voxelSize, maxPoints
- [x] 3.3 Implement copyWith and equality for PerformanceConfig
- [x] 3.4 Update ViewerConfig to include PerformanceConfig

## 4. Widget Integration

- [x] 4.1 Update PcdView widget to accept PerformanceConfig
- [x] 4.2 Pass optimization settings to Rust parser via FFI
- [x] 4.3 Add loading indicator for optimization phase
- [x] 4.4 Display optimization results in status (points before/after)

## 5. Example App UI

- [x] 5.1 Add performance settings section to example app
- [x] 5.2 Add toggle for deduplication
- [x] 5.3 Add slider for voxel size (0.01m to 1.0m)
- [x] 5.4 Add slider/input for max points
- [x] 5.5 Display current point count and optimization stats

## 6. Testing & Documentation

- [x] 6.1 Add integration tests with large PCD files
- [x] 6.2 Benchmark performance before/after optimization
- [x] 6.3 Update README with optimization feature documentation
