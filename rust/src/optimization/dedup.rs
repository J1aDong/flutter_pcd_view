use crate::parser::Point3D;
use std::collections::HashSet;

/// Remove duplicate points using spatial hashing.
///
/// # Arguments
/// * `points` - Input point cloud
/// * `precision` - Grid cell size for quantization (smaller = more precise matching)
///
/// # Returns
/// Points with duplicates removed, preserving first occurrence color
pub fn deduplicate_points(points: &[Point3D], precision: f64) -> Vec<Point3D> {
    if precision <= 0.0 {
        return points.to_vec();
    }

    let mut seen: HashSet<(i64, i64, i64)> = HashSet::with_capacity(points.len());
    let mut result = Vec::with_capacity(points.len());

    let inv_precision = 1.0 / precision;

    for point in points {
        // Quantize coordinates to grid cells
        let key = (
            (point.x * inv_precision).round() as i64,
            (point.y * inv_precision).round() as i64,
            (point.z * inv_precision).round() as i64,
        );

        if seen.insert(key) {
            result.push(point.clone());
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_point(x: f64, y: f64, z: f64, color: u32) -> Point3D {
        Point3D { x, y, z, color }
    }

    #[test]
    fn test_no_duplicates() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(1.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(0.0, 1.0, 0.0, 0xFFFFFFFF),
        ];
        let result = deduplicate_points(&points, 0.001);
        assert_eq!(result.len(), 3);
    }

    #[test]
    fn test_exact_duplicates() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_point(0.0, 0.0, 0.0, 0xFF00FF00),
            create_point(0.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let result = deduplicate_points(&points, 0.001);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].color, 0xFFFF0000); // First occurrence preserved
    }

    #[test]
    fn test_near_duplicates() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_point(0.0005, 0.0005, 0.0005, 0xFF00FF00), // Within precision
            create_point(1.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let result = deduplicate_points(&points, 0.01);
        assert_eq!(result.len(), 2); // First two considered same
    }

    #[test]
    fn test_zero_precision() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
        ];
        let result = deduplicate_points(&points, 0.0);
        assert_eq!(result.len(), 2); // No dedup when precision is 0
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let result = deduplicate_points(&points, 0.001);
        assert!(result.is_empty());
    }

    #[test]
    fn test_negative_precision() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
        ];
        let result = deduplicate_points(&points, -0.1);
        assert_eq!(result.len(), 2); // No dedup for negative precision
    }
}
