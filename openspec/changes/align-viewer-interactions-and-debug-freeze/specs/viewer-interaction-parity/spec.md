## ADDED Requirements

### Requirement: Provide reference-aligned camera gestures
The viewer SHALL provide camera gestures aligned with the reference PointCloudDataViewer interaction model for touch and pointer input.

#### Scenario: Rotate point cloud by dragging
- **WHEN** the user drags on the viewer canvas
- **THEN** the camera rotates according to drag direction without requiring the file to reload

#### Scenario: Zoom with pinch gesture
- **WHEN** the user performs a pinch gesture on the viewer canvas
- **THEN** the camera zoom level updates smoothly within configured bounds

#### Scenario: Zoom with mouse wheel or trackpad scroll
- **WHEN** the user scrolls over the viewer canvas with pointer input
- **THEN** the camera zoom level updates without blocking other viewer interactions

### Requirement: Preserve usable viewer state during navigation
The viewer SHALL preserve the latest camera state so the demo can return from the viewer without forcing a full interaction reset.

#### Scenario: Return from viewer after interaction
- **WHEN** the user navigates back after rotating or zooming the point cloud
- **THEN** the latest camera/controller state is available to the caller for reuse

#### Scenario: Keep controls usable while viewer is active
- **WHEN** the viewer screen is showing a loaded point cloud
- **THEN** point size and other screen-level controls remain operable alongside the gesture layer
