## 1. Rust Processing Module Setup

- [x] 1.1 Create `rust/src/processing/mod.rs` module structure
- [x] 1.2 Add KD-Tree dependency (kd-tree crate or custom implementation)
- [x] 1.3 Define processing pipeline types and traits

## 2. Outlier Removal Implementation

- [x] 2.1 Create `rust/src/processing/outlier.rs` module
- [x] 2.2 Implement SOR (Statistical Outlier Removal) algorithm
- [x] 2.3 Implement ROR (Radius Outlier Removal) algorithm
- [x] 2.4 Add unit tests for outlier removal
- [x] 2.5 Add configurable parameters (k, std_ratio, radius, min_neighbors)

## 3. Point Connectivity Implementation

- [x] 3.1 Create `rust/src/processing/connectivity.rs` module
- [x] 3.2 Implement sequential connection mode
- [x] 3.3 Implement KD-Tree nearest neighbor connection mode
- [x] 3.4 Add line segment generation with max distance threshold
- [x] 3.5 Add unit tests for connectivity

## 4. Point Cloud Merge Implementation

- [x] 4.1 Create `rust/src/processing/merge.rs` module
- [x] 4.2 Implement multi-pointcloud merge function
- [x] 4.3 Implement source color assignment
- [x] 4.4 Add unit tests for merge

## 5. FFI Bridge Updates

- [x] 5.1 Define ProcessingConfig struct in Rust API
- [x] 5.2 Define SORConfig and RORConfig structs
- [x] 5.3 Define ConnectConfig struct for line mode
- [x] 5.4 Update API to accept processing configuration
- [x] 5.5 Run flutter_rust_bridge code generation
- [x] 5.6 Verify generated Dart bindings compile correctly

## 6. Flutter Configuration

- [x] 6.1 Add ProcessingConfig class to viewer_config.dart
- [x] 6.2 Add SOR and ROR configuration fields
- [x] 6.3 Add connectivity/render mode configuration
- [x] 6.4 Add merge configuration fields
- [x] 6.5 Implement copyWith and equality for new configs

## 7. Widget Integration

- [x] 7.1 Update PcdView to support line rendering mode
- [x] 7.2 Pass processing settings to Rust via FFI
- [x] 7.3 Add processing stats callback (ProcessingStats)
- [x] 7.4 Support LineSegmentData from Rust for connectivity

## 8. Example App UI

- [x] 8.1 Add outlier removal settings section (SOR/ROR)
- [x] 8.2 Add connectivity/line mode settings section
- [x] 8.3 Add reset buttons for processing settings
- [x] 8.4 Display processing statistics in UI

## 9. Testing & Documentation

- [x] 9.1 Run all Rust unit tests (63 passed)
- [x] 9.2 Run Flutter analyze (no issues)
- [ ] 9.3 Update README with new features