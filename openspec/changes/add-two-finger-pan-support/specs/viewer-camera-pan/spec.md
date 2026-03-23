## ADDED Requirements

### Requirement: Two-finger pan support
The system SHALL allow users to pan the native point cloud viewer by dragging with two fingers.

#### Scenario: Pan view with two-finger drag
- **WHEN** the user places two fingers on the viewer and moves the gesture focal point
- **THEN** the viewer SHALL update the camera pan offset so the visible region moves accordingly

#### Scenario: Preserve one-finger rotation
- **WHEN** the user drags with a single finger
- **THEN** the viewer SHALL continue updating camera rotation without applying two-finger pan behavior

### Requirement: Two-finger pan works with zoom
The system SHALL keep two-finger pan compatible with pinch zoom during the same gesture.

#### Scenario: Pan and zoom in one gesture
- **WHEN** the user performs a two-finger gesture that both changes focal-point position and pinch scale
- **THEN** the viewer SHALL apply both the pan offset change and the zoom change from that gesture update

#### Scenario: Mouse-wheel zoom remains unchanged
- **WHEN** the user zooms using a pointer scroll event
- **THEN** the viewer SHALL continue updating zoom without modifying the current pan offset

### Requirement: Pan state is part of camera state
The system SHALL persist camera pan as part of the viewer camera state across Flutter and native renderer updates.

#### Scenario: Renderer update keeps pan state
- **WHEN** the viewer rebuilds or re-sends camera state to the native renderer after a scene or viewport update
- **THEN** the current pan offset SHALL be preserved and reapplied with rotation and zoom

#### Scenario: Default camera has no pan offset
- **WHEN** the viewer or camera controller is created without explicit pan values
- **THEN** the camera pan offset SHALL default to zero on both axes
