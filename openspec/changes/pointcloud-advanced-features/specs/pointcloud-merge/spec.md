## ADDED Requirements

### Requirement: Multiple point cloud input
The system SHALL support loading and merging multiple point cloud files.

#### Scenario: Merge two point clouds
- **WHEN** two PCD files are selected for merging
- **THEN** both point clouds SHALL be combined into a single dataset

#### Scenario: Preserve all points during merge
- **WHEN** merging point clouds with 1000 and 2000 points
- **THEN** the merged result SHALL contain 3000 points

### Requirement: Source color assignment
The system SHALL support assigning distinct colors to different point cloud sources.

#### Scenario: Auto-assign source colors
- **WHEN** auto-color mode is enabled for merging
- **THEN** each source point cloud SHALL be rendered with a distinct color

#### Scenario: Custom source colors
- **WHEN** user specifies colors [red, blue] for two sources
- **THEN** the first source SHALL be rendered in red, the second in blue

### Requirement: Merge with optimization
The system SHALL support applying optimization after merging.

#### Scenario: Merge then downsample
- **WHEN** merging is followed by voxel downsampling with size 0.1m
- **THEN** the merged result SHALL be downsampled before rendering

#### Scenario: Merge then deduplicate
- **WHEN** merging is followed by deduplication
- **THEN** overlapping points from different sources SHALL be deduplicated

### Requirement: Merge statistics
The system SHALL report merge operation results.

#### Scenario: Report merge counts
- **WHEN** multiple point clouds are merged
- **THEN** the system SHALL report point count for each source and total count
