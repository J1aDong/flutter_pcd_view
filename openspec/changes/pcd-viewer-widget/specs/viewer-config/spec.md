## ADDED Requirements

### Requirement: Configure point rendering size
The system SHALL allow configuration of point size for rendering.

#### Scenario: Set initial point size
- **WHEN** ViewerConfig is created with pointSize parameter
- **THEN** points render with the specified size

#### Scenario: Update point size dynamically
- **WHEN** user changes pointSize value
- **THEN** view updates to reflect new point size immediately

### Requirement: Configure grid display range
The system SHALL allow configuration of grid dimensions and visibility.

#### Scenario: Set grid X range
- **WHEN** ViewerConfig specifies gridRangeXStart and gridRangeXEnd
- **THEN** grid displays within the specified X bounds

#### Scenario: Set grid Y range
- **WHEN** ViewerConfig specifies gridRangeYStart and gridRangeYEnd
- **THEN** grid displays within the specified Y bounds

#### Scenario: Toggle grid visibility
- **WHEN** ViewerConfig sets showGrid to false
- **THEN** grid is hidden from view

### Requirement: Configure background color
The system SHALL allow customization of the viewer background color.

#### Scenario: Set custom background color
- **WHEN** ViewerConfig specifies backgroundColor
- **THEN** viewer displays with the specified background color

#### Scenario: Use default background color
- **WHEN** ViewerConfig does not specify backgroundColor
- **THEN** viewer uses black as default background

### Requirement: Configure coordinate axes display
The system SHALL allow toggling coordinate axes visibility.

#### Scenario: Show coordinate axes
- **WHEN** ViewerConfig sets showAxes to true
- **THEN** X/Y/Z axes are visible in the scene

#### Scenario: Hide coordinate axes
- **WHEN** ViewerConfig sets showAxes to false
- **THEN** axes are hidden from view

### Requirement: Configure camera initial position
The system SHALL allow setting initial camera rotation and zoom.

#### Scenario: Set initial rotation
- **WHEN** ViewerConfig specifies rotationX, rotationY, rotationZ
- **THEN** camera starts with the specified rotation angles

#### Scenario: Set initial zoom level
- **WHEN** ViewerConfig specifies initialScale
- **THEN** camera starts with the specified zoom level

#### Scenario: Set zoom limits
- **WHEN** ViewerConfig specifies minScale and maxScale
- **THEN** user cannot zoom beyond the specified limits
