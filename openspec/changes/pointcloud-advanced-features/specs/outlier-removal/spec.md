## ADDED Requirements

### Requirement: Statistical Outlier Removal (SOR)
The system SHALL support removing points based on statistical analysis of local density.

#### Scenario: Remove statistical outliers
- **WHEN** SOR is enabled with k=50 neighbors and std_ratio=1.0
- **THEN** points with average neighbor distance beyond 1 standard deviation SHALL be removed

#### Scenario: SOR preserves dense regions
- **WHEN** SOR is applied to a point cloud with dense regions and sparse outliers
- **THEN** dense regions SHALL be preserved while sparse outliers SHALL be removed

#### Scenario: Configurable SOR parameters
- **WHEN** user sets k=30 and std_ratio=2.0
- **THEN** the algorithm SHALL use 30 nearest neighbors and 2.0 standard deviation threshold

### Requirement: Radius Outlier Removal (ROR)
The system SHALL support removing points based on neighbor count within radius.

#### Scenario: Remove radius outliers
- **WHEN** ROR is enabled with radius=0.1m and min_neighbors=5
- **THEN** points with fewer than 5 neighbors within 0.1m radius SHALL be removed

#### Scenario: ROR preserves clustered points
- **WHEN** ROR is applied to a point cloud with clusters and isolated points
- **THEN** clustered points SHALL be preserved while isolated points SHALL be removed

#### Scenario: Configurable ROR parameters
- **WHEN** user sets radius=0.2m and min_neighbors=3
- **THEN** the algorithm SHALL use 0.2m radius and 3 minimum neighbors threshold

### Requirement: Combined outlier removal
The system SHALL support applying SOR and ROR in sequence.

#### Scenario: Apply SOR then ROR
- **WHEN** both SOR and ROR are enabled
- **THEN** SOR SHALL be applied first, followed by ROR on the remaining points

#### Scenario: Track removal statistics
- **WHEN** outlier removal is applied
- **THEN** the system SHALL report original count, after SOR count, and final count
