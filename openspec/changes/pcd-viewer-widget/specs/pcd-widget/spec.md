## ADDED Requirements

### Requirement: Provide PcdView widget
The system SHALL provide a PcdView widget that displays point cloud data in an interactive 3D viewer.

#### Scenario: Display point cloud from file path
- **WHEN** user provides a PCD file path to PcdView widget
- **THEN** widget loads and displays the point cloud in 3D space

#### Scenario: Display point cloud from parsed data
- **WHEN** user provides pre-parsed point cloud data to PcdView widget
- **THEN** widget displays the data without re-parsing

### Requirement: Support gesture-based camera control
The system SHALL allow users to manipulate the 3D view using touch gestures.

#### Scenario: Rotate view with drag gesture
- **WHEN** user drags on the screen
- **THEN** camera rotates around the point cloud following the drag direction

#### Scenario: Zoom with pinch gesture
- **WHEN** user performs pinch-to-zoom gesture
- **THEN** camera zooms in or out maintaining the focal point

#### Scenario: Zoom with scroll wheel
- **WHEN** user scrolls mouse wheel (desktop/web)
- **THEN** camera zooms in or out smoothly

### Requirement: Render point cloud with configurable appearance
The system SHALL render point cloud points with customizable size and color.

#### Scenario: Adjust point size
- **WHEN** user sets pointSize parameter
- **THEN** all points render with the specified pixel size

#### Scenario: Preserve point colors from PCD file
- **WHEN** PCD file contains color information
- **THEN** points render with their original colors

#### Scenario: Use default color for colorless points
- **WHEN** PCD file contains only XYZ data
- **THEN** points render with white color by default

### Requirement: Display 3D scene helpers
The system SHALL optionally display grid and coordinate axes to aid spatial understanding.

#### Scenario: Show grid plane
- **WHEN** showGrid is enabled
- **THEN** widget displays a grid on the ground plane

#### Scenario: Show coordinate axes
- **WHEN** showAxes is enabled
- **THEN** widget displays X/Y/Z axes with distinct colors

### Requirement: Use DiTreDi for 3D rendering
The system SHALL use DiTreDi library as the underlying 3D rendering engine.

#### Scenario: Integrate with DiTreDi controller
- **WHEN** PcdView is initialized
- **THEN** widget creates and manages a DiTreDiController for camera state

#### Scenario: Support custom DiTreDi configuration
- **WHEN** user provides custom DiTreDiController
- **THEN** widget uses the provided controller instead of creating default one
