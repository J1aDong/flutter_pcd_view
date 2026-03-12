## MODIFIED Requirements

### Requirement: Performance configuration options
The system SHALL provide configuration options for point cloud optimization and processing settings.

#### Scenario: Configure deduplication
- **WHEN** user sets deduplication enabled to true
- **THEN** duplicate points SHALL be removed during loading

#### Scenario: Configure voxel size
- **WHEN** user sets voxel size to 0.05
- **THEN** downsampling SHALL use 5cm voxels

#### Scenario: Configure max points
- **WHEN** user sets max points to 50000
- **THEN** output SHALL be limited to at most 50000 points

#### Scenario: Configure SOR outlier removal
- **WHEN** user enables SOR with k=50 and std_ratio=1.0
- **THEN** statistical outlier removal SHALL be applied with those parameters

#### Scenario: Configure ROR outlier removal
- **WHEN** user enables ROR with radius=0.1 and min_neighbors=5
- **THEN** radius outlier removal SHALL be applied with those parameters

#### Scenario: Configure line connection mode
- **WHEN** user sets render mode to "lines" with max_distance=0.5
- **THEN** points SHALL be connected as lines using nearest neighbor within 0.5m

## ADDED Requirements

### Requirement: Processing pipeline configuration
The system SHALL provide a unified processing pipeline that combines optimization and processing steps.

#### Scenario: Configure full pipeline
- **WHEN** user enables dedup, SOR, voxel, and max points
- **THEN** processing SHALL apply in order: dedup → SOR → voxel → max points

#### Scenario: Processing stats callback
- **WHEN** processing pipeline completes
- **THEN** callback SHALL receive stats for each processing step
