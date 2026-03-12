## ADDED Requirements

### Requirement: Sequential point connection
The system SHALL support connecting points in file order to form continuous line segments.

#### Scenario: Connect points sequentially
- **WHEN** sequential connection mode is enabled
- **THEN** points SHALL be connected in the order they appear in the file

#### Scenario: Limit line segment count
- **WHEN** max line segments is set to 1000
- **THEN** only the first 1000 segments SHALL be rendered

### Requirement: Nearest neighbor point connection
The system SHALL support connecting points based on spatial proximity using KD-Tree.

#### Scenario: Connect by nearest neighbor
- **WHEN** nearest neighbor mode is enabled with max distance 0.5m
- **THEN** each point SHALL be connected to its nearest neighbor within 0.5m

#### Scenario: No connection beyond threshold
- **WHEN** the nearest neighbor is beyond the max distance threshold
- **THEN** no connection SHALL be created for that point

### Requirement: Line rendering mode
The system SHALL support rendering point cloud as lines instead of individual points.

#### Scenario: Switch to line mode
- **WHEN** rendering mode is set to "lines"
- **THEN** points SHALL be rendered as connected line segments

#### Scenario: Line width configuration
- **WHEN** line width is set to 2.0
- **THEN** all line segments SHALL be rendered with 2.0 pixel width

### Requirement: Connection color options
The system SHALL support color options for line segments.

#### Scenario: Use point colors for lines
- **WHEN** line color mode is "per-point"
- **THEN** each line segment SHALL use gradient colors from start to end point

#### Scenario: Use uniform line color
- **WHEN** line color mode is "uniform" with color red
- **THEN** all line segments SHALL be rendered in red
