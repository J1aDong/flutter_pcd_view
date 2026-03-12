#[cfg(test)]
mod tests {
    use super::super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    fn create_test_pcd_file(content: &str) -> NamedTempFile {
        let mut file = NamedTempFile::new().unwrap();
        file.write_all(content.as_bytes()).unwrap();
        file.flush().unwrap();
        file
    }

    #[test]
    fn test_parse_ascii_xyz() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 3
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 3
DATA ascii
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 3);

        assert_eq!(points[0].x, 0.0);
        assert_eq!(points[0].y, 0.0);
        assert_eq!(points[0].z, 0.0);
        assert_eq!(points[0].color, 0xFFFFFFFF); // Default white

        assert_eq!(points[1].x, 1.0);
        assert_eq!(points[2].y, 1.0);
    }

    #[test]
    fn test_parse_ascii_xyzrgb() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z rgb
SIZE 4 4 4 4
TYPE F F F F
COUNT 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
0.0 0.0 0.0 16711680
1.0 1.0 1.0 65280
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        // First point: red (0x00FF0000 -> 0xFFFF0000 with alpha)
        assert_eq!(points[0].color, 0xFFFF0000);

        // Second point: green (0x0000FF00 -> 0xFF00FF00 with alpha)
        assert_eq!(points[1].color, 0xFF00FF00);
    }

    #[test]
    fn test_parse_ascii_xyzhsv() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z h s v
SIZE 4 4 4 4 4 4
TYPE F F F F F F
COUNT 1 1 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
0.0 0.0 0.0 0.0 1.0 1.0
1.0 1.0 1.0 120.0 1.0 1.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        // First point: H=0, S=1, V=1 -> Red
        assert_eq!(points[0].color & 0x00FFFFFF, 0x00FF0000);

        // Second point: H=120, S=1, V=1 -> Green
        assert_eq!(points[1].color & 0x00FFFFFF, 0x0000FF00);
    }

    #[test]
    fn test_hsv_to_rgb_conversion() {
        // Red
        let rgb = hsv_to_rgb(0.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFFFF0000);

        // Green
        let rgb = hsv_to_rgb(120.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFF00FF00);

        // Blue
        let rgb = hsv_to_rgb(240.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFF0000FF);

        // White
        let rgb = hsv_to_rgb(0.0, 0.0, 1.0);
        assert_eq!(rgb, 0xFFFFFFFF);

        // Black
        let rgb = hsv_to_rgb(0.0, 0.0, 0.0);
        assert_eq!(rgb, 0xFF000000);
    }

    #[test]
    fn test_parse_binary_xyz() {
        // Create binary PCD with 2 points
        let mut content = String::from(r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA binary
"#);

        let mut file = NamedTempFile::new().unwrap();
        file.write_all(content.as_bytes()).unwrap();

        // Write binary data: two points (x, y, z as f32)
        let point1: [f32; 3] = [1.0, 2.0, 3.0];
        let point2: [f32; 3] = [4.0, 5.0, 6.0];

        for &val in &point1 {
            file.write_all(&val.to_le_bytes()).unwrap();
        }
        for &val in &point2 {
            file.write_all(&val.to_le_bytes()).unwrap();
        }
        file.flush().unwrap();

        let result = parse_pcd_file(file.path().to_str().unwrap());
        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        assert_eq!(points[0].x, 1.0);
        assert_eq!(points[0].y, 2.0);
        assert_eq!(points[0].z, 3.0);

        assert_eq!(points[1].x, 4.0);
        assert_eq!(points[1].y, 5.0);
        assert_eq!(points[1].z, 6.0);
    }

    #[test]
    fn test_invalid_file() {
        let result = parse_pcd_file("/nonexistent/file.pcd");
        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_header() {
        let content = "This is not a valid PCD file";
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());
        assert!(result.is_err());
    }

    #[test]
    fn test_missing_required_fields() {
        let content = r#"VERSION 0.7
FIELDS x y z
DATA ascii
0.0 0.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());
        assert!(result.is_err());
    }

    #[test]
    fn test_unsupported_field_type() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z intensity
SIZE 4 4 4 4
TYPE F F F F
COUNT 1 1 1 1
WIDTH 1
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 1
DATA ascii
0.0 0.0 0.0 100.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());
        // Should still parse but ignore unsupported field
        assert!(result.is_ok());
    }

    #[test]
    fn test_point_count_mismatch() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
0.0 0.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap());
        // Should handle gracefully
        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 1); // Only one point was provided
    }

    #[test]
    fn test_large_point_cloud() {
        let mut content = String::from(r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 1000
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 1000
DATA ascii
"#);

        for i in 0..1000 {
            content.push_str(&format!("{}.0 {}.0 {}.0\n", i, i, i));
        }

        let file = create_test_pcd_file(&content);
        let result = parse_pcd_file(file.path().to_str().unwrap());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 1000);
    }

    #[test]
    fn test_rgb_color_conversion() {
        // Test decimal RGB to ARGB conversion
        let rgb_decimal = 16711680.0; // Red in decimal (0x00FF0000)
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFFFF0000);

        let rgb_decimal = 65280.0; // Green in decimal (0x0000FF00)
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFF00FF00);

        let rgb_decimal = 255.0; // Blue in decimal (0x000000FF)
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFF0000FF);
    }
}
