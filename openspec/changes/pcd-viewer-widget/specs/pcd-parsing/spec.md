## ADDED Requirements

### Requirement: Parse ASCII format PCD files
The system SHALL parse PCD files in ASCII format and extract point cloud data including coordinates and optional color information.

#### Scenario: Parse XYZ-only ASCII file
- **WHEN** user provides a PCD file with FIELDS x y z
- **THEN** system returns a list of 3D points with coordinates only

#### Scenario: Parse XYZRGB ASCII file
- **WHEN** user provides a PCD file with FIELDS x y z rgb
- **THEN** system returns a list of 3D points with coordinates and RGB color values

#### Scenario: Parse XYZHSV ASCII file
- **WHEN** user provides a PCD file with FIELDS x y z hsv
- **THEN** system returns a list of 3D points with coordinates and HSV color values

### Requirement: Parse Binary format PCD files
The system SHALL parse PCD files in binary format for improved performance on large datasets.

#### Scenario: Parse binary PCD file
- **WHEN** user provides a PCD file with DATA binary
- **THEN** system parses the file using binary decoding and returns point cloud data

### Requirement: Validate PCD file format
The system SHALL validate PCD file headers and reject invalid files with clear error messages.

#### Scenario: Invalid header format
- **WHEN** user provides a file with missing or malformed PCD header
- **THEN** system returns an error indicating which header field is invalid

#### Scenario: Unsupported field type
- **WHEN** user provides a PCD file with unsupported FIELDS configuration
- **THEN** system returns an error listing supported field types

### Requirement: Use Rust for parsing performance
The system SHALL implement PCD parsing in Rust and expose it to Flutter via FFI for optimal performance.

#### Scenario: Parse large PCD file efficiently
- **WHEN** user loads a PCD file with 1M+ points
- **THEN** system completes parsing in under 2 seconds on mid-range mobile devices

#### Scenario: Cross-platform compatibility
- **WHEN** library is built for Android or iOS
- **THEN** Rust parser compiles and links correctly on both platforms

### Requirement: Handle color format conversion
The system SHALL convert packed RGB decimal values to Flutter Color objects.

#### Scenario: Convert packed RGB to ARGB hex
- **WHEN** PCD file contains rgb field with decimal value (e.g., 16711680 for red)
- **THEN** system converts to Flutter Color with format 0xFFrrggbb
