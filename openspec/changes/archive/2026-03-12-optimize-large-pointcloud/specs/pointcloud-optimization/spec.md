## ADDED Requirements

### Requirement: Point deduplication
The system SHALL remove duplicate points based on spatial coordinates during PCD parsing.

#### Scenario: Deduplicate identical points
- **WHEN** a PCD file contains multiple points at identical coordinates
- **THEN** only one point SHALL be retained at each unique position

#### Scenario: Preserve first occurrence color
- **WHEN** duplicate points have different colors
- **THEN** the color of the first occurrence SHALL be preserved

### Requirement: Voxel grid downsampling
The system SHALL support voxel grid downsampling to reduce point count while preserving spatial structure.

#### Scenario: Downsample with specified voxel size
- **WHEN** downsampling is enabled with voxel size 0.1
- **THEN** all points within each 0.1m³ voxel SHALL be replaced by their centroid

#### Scenario: Average colors during downsampling
- **WHEN** downsampling colored point clouds
- **THEN** output point color SHALL be the average of all input point colors in the voxel

#### Scenario: Disable downsampling by default
- **WHEN** no voxel size is specified
- **THEN** downsampling SHALL be disabled and all points SHALL be returned

### Requirement: Maximum point count limit
The system SHALL support limiting the maximum number of points returned.

#### Scenario: Limit to max points
- **WHEN** max points is set to 100000 and input has 500000 points
- **THEN** exactly 100000 points SHALL be returned after optimization

#### Scenario: No limit when disabled
- **WHEN** max points is not set or set to 0
- **THEN** no point count limit SHALL be applied

### Requirement: Optimization pipeline order
The system SHALL apply optimizations in a specific order: deduplication, then downsampling, then max points limit.

#### Scenario: Apply optimizations in order
- **WHEN** all three optimizations are enabled
- **THEN** deduplication SHALL run first, followed by downsampling, then max points limit

### Requirement: Optimization settings are optional
The system SHALL allow each optimization to be independently enabled or disabled.

#### Scenario: Enable only deduplication
- **WHEN** only deduplication is enabled
- **THEN** only duplicate points SHALL be removed without other modifications

#### Scenario: Enable only downsampling
- **WHEN** only voxel grid downsampling is enabled
- **THEN** spatial downsampling SHALL be applied without deduplication

### Requirement: Preserve point cloud bounds
The system SHALL preserve the original bounding box of the point cloud after optimization.

#### Scenario: Bounds preserved after optimization
- **WHEN** optimization is applied to a point cloud
- **THEN** the axis-aligned bounding box of the output SHALL approximately match the input
