use crate::parser::Point3D;

/// Limit the number of points using uniform sampling.
///
/// When the point cloud exceeds max_points, uniformly samples points
/// to maintain spatial distribution.
///
/// # Arguments
/// * `points` - Input point cloud
/// * `max_points` - Maximum number of points to return (0 = no limit)
///
/// # Returns
/// Point cloud limited to max_points, or original if under limit
pub fn limit_points(points: &[Point3D], max_points: usize) -> Vec<Point3D> {
    if max_points == 0 || points.len() <= max_points {
        return points.to_vec();
    }

    // Use stride-based uniform sampling to preserve spatial distribution
    let stride = points.len() as f64 / max_points as f64;
    let mut result = Vec::with_capacity(max_points);

    for i in 0..max_points {
        let idx = (i as f64 * stride).round() as usize;
        let idx = idx.min(points.len() - 1); // Clamp to valid range
        result.push(points[idx].clone());
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_point(x: f64, y: f64, z: f64) -> Point3D {
        Point3D { x, y, z, color: 0xFFFFFFFF }
    }

    #[test]
    fn test_under_limit() {
        let points = vec![
            create_point(0.0, 0.0, 0.0),
            create_point(1.0, 0.0, 0.0),
        ];
        let result = limit_points(&points, 10);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_exact_limit() {
        let points = vec![
            create_point(0.0, 0.0, 0.0),
            create_point(1.0, 0.0, 0.0),
        ];
        let result = limit_points(&points, 2);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_over_limit() {
        let points: Vec<Point3D> = (0..100).map(|i| create_point(i as f64, 0.0, 0.0)).collect();
        let result = limit_points(&points, 50);
        assert_eq!(result.len(), 50);
    }

    #[test]
    fn test_zero_limit() {
        let points = vec![create_point(0.0, 0.0, 0.0)];
        let result = limit_points(&points, 0);
        assert_eq!(result.len(), 1); // No limit applied
    }

    #[test]
    fn test_preserves_spatial_coverage() {
        // Points from 0 to 99, limit to 2 should give first and middle
        let points: Vec<Point3D> = (0..100).map(|i| create_point(i as f64, 0.0, 0.0)).collect();
        let result = limit_points(&points, 2);
        assert_eq!(result.len(), 2);
        // First point should be near start
        assert!((result[0].x - 0.0).abs() < 1.0);
        // Second point should be near middle (uniform sampling with stride=50)
        assert!((result[1].x - 50.0).abs() < 1.0);
    }

    #[test]
    fn test_uniform_distribution() {
        // Create 100 points and limit to 10
        let points: Vec<Point3D> = (0..100).map(|i| create_point(i as f64, 0.0, 0.0)).collect();
        let result = limit_points(&points, 10);
        assert_eq!(result.len(), 10);

        // Check that points are roughly uniformly distributed
        // Each sampled point should be approximately 10 apart
        for i in 1..result.len() {
            let diff = (result[i].x - result[i - 1].x).abs();
            assert!(diff > 5.0 && diff < 15.0, "Expected ~10 spacing, got {}", diff);
        }
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let result = limit_points(&points, 10);
        assert!(result.is_empty());
    }
}
