## Context

The current PCD viewer loads all points from a file without any optimization. Real-world LiDAR scans often contain 1M+ points, causing:
- UI freeze during loading (blocking the main isolate)
- Slow rendering (all points sent to GPU)
- Laggy interactions (pan/zoom/rotate)

The project uses flutter_rust_bridge for FFI, with Rust handling PCD parsing and Flutter/DiTreDi handling rendering. This design leverages Rust's performance for optimization.

Reference project (PointCloudDataViewer_flutter) has similar issues - pure Dart implementation with no optimization.

## Goals / Non-Goals

**Goals:**
- Reduce point count for large files to improve performance
- Preserve spatial structure and visual quality during downsampling
- Provide user control over optimization settings
- Maintain backward compatibility (default behavior unchanged)

**Non-Goals:**
- GPU-based point cloud processing
- Changing the DiTreDi rendering library
- Real-time streaming from network sources
- Point cloud compression algorithms (e.g., Draco)

## Decisions

### 1. Voxel Grid Downsampling Algorithm

**Decision**: Use voxel grid downsampling (industry standard)

**Rationale**:
- Preserves spatial distribution - points are sampled evenly across space
- Predictable output size based on voxel size parameter
- Used by PCL (Point Cloud Library), Open3D, and other standard tools
- Alternative considered: Random sampling (faster but loses spatial structure)
- Alternative considered: Octree-based (more complex, similar results)

**Implementation**:
1. Divide 3D space into cubic voxels of specified size
2. For each voxel, compute centroid of all points within
3. Replace all points in voxel with centroid point
4. Average colors for RGB point clouds

### 2. Deduplication via Spatial Hashing

**Decision**: Use spatial hashing for O(n) deduplication

**Rationale**:
- Simple and fast for detecting duplicate coordinates
- Hash map provides O(1) lookup for already-seen positions
- Alternative considered: Sorting + adjacent comparison (O(n log n), more complex)
- Memory-efficient compared to full spatial index structures

**Implementation**:
1. Quantize coordinates to grid cells (configurable precision)
2. Use quantized coordinates as hash key
3. First point at each key wins, duplicates skipped
4. Preserve color from first occurrence

### 3. Optimization Pipeline Order

**Decision**: Deduplication → Downsampling → Max Points Limit

**Rationale**:
- Deduplication first removes obvious redundancy
- Downsampling then handles spatial distribution
- Max points is final safety limit for extreme cases
- Each step is optional and configurable

### 4. Flutter Settings API

**Decision**: Add settings to `ViewerConfig` and expose via constructor parameters

**Rationale**:
- Consistent with existing `ViewerConfig` pattern
- Immutable configuration with `copyWith`
- Easy to add UI controls in example app

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Quality loss from aggressive downsampling | Default voxel size preserves detail; user configurable |
| Memory spike during optimization | Process in chunks if needed; stream results |
| Breaking existing API | All new parameters optional with sensible defaults |
| Incorrect deduplication of valid close points | Configurable precision tolerance |

## Migration Plan

1. Add optimization functions to Rust layer
2. Update FFI bindings (automatic via flutter_rust_bridge)
3. Add settings to ViewerConfig
4. Update PcdView widget to use optimization
5. Add settings UI in example app

No rollback needed - all changes are additive with opt-in behavior.
