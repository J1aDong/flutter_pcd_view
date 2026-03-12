## Requirements

### Requirement: Performance configuration options
The system SHALL provide configuration options for point cloud optimization settings.

#### Scenario: Configure deduplication
- **WHEN** user sets deduplication enabled to true
- **THEN** duplicate points SHALL be removed during loading

#### Scenario: Configure voxel size
- **WHEN** user sets voxel size to 0.05
- **THEN** downsampling SHALL use 5cm voxels

#### Scenario: Configure max points
- **WHEN** user sets max points to 50000
- **THEN** output SHALL be limited to at most 50000 points

### Requirement: Default optimization settings
The system SHALL provide sensible default values that preserve original behavior.

#### Scenario: Default settings preserve all points
- **WHEN** no optimization settings are specified
- **THEN** all points SHALL be loaded without modification

### Requirement: Settings integration with PcdView
The PcdView widget SHALL accept and apply optimization settings.

#### Scenario: Apply settings from config
- **WHEN** PcdView is created with a PerformanceConfig
- **THEN** the optimization settings SHALL be used during point cloud loading

### Requirement: Settings immutability
Optimization settings SHALL be immutable and support the copyWith pattern.

#### Scenario: Create modified copy
- **WHEN** user calls copyWith with new voxel size
- **THEN** a new config object SHALL be returned with the updated value
