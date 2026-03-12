## ADDED Requirements

### Requirement: Keep large-file loading responsive
The system SHALL load large PCD files without making the viewer screen or back navigation appear frozen to the user.

#### Scenario: Show loading state before large file is ready
- **WHEN** the user opens a large PCD file such as `pointcloud_map.pcd`
- **THEN** the viewer shows an explicit loading state while keeping the UI responsive to lifecycle events

#### Scenario: Ignore stale load result after leaving viewer
- **WHEN** the user leaves the viewer before an in-flight load finishes
- **THEN** the completed result is ignored instead of reactivating or blocking the previous screen

### Requirement: Avoid redundant heavy work for display-only changes
The system SHALL distinguish file-data work from display-only updates so point-size or helper changes do not restart the full load pipeline.

#### Scenario: Adjust point size after file is loaded
- **WHEN** the user changes point size for an already loaded file
- **THEN** the viewer updates presentation without reparsing the source PCD file

#### Scenario: Toggle grid or axes after file is loaded
- **WHEN** the user changes helper visibility or background-related viewer settings
- **THEN** the viewer applies the change without repeating the original large-file parse

### Requirement: Serialize file playback and file switching work
The demo SHALL prevent overlapping heavy viewer jobs when switching files or advancing playback.

#### Scenario: Switch to another file while current load is active
- **WHEN** a new file selection or playback step starts before the prior load completes
- **THEN** the older job is cancelled or marked stale so only the latest request can update the viewer
