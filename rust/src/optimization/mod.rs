mod dedup;
mod voxel_grid;
mod max_points;
mod pipeline;

pub use dedup::deduplicate_points;
pub use voxel_grid::voxel_grid_downsample;
pub use max_points::limit_points;
pub use pipeline::{OptimizationConfig, optimize_points, optimize_points_with_stats};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::Point3D;

    fn create_test_point(x: f64, y: f64, z: f64, color: u32) -> Point3D {
        Point3D { x, y, z, color }
    }

    #[test]
    fn test_dedup_basic() {
        let points = vec![
            create_test_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_test_point(0.0, 0.0, 0.0, 0xFF00FF00), // duplicate
            create_test_point(1.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let result = deduplicate_points(&points, 0.001);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].color, 0xFFFF0000); // first occurrence preserved
    }

    #[test]
    fn test_voxel_grid_basic() {
        let points = vec![
            create_test_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_test_point(0.05, 0.05, 0.05, 0xFF00FF00),
            create_test_point(1.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let result = voxel_grid_downsample(&points, 0.5);
        // Points 0 and 1 are in the same 0.5m voxel, point 2 is in another
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_max_points_limiting() {
        let points: Vec<Point3D> = (0..100)
            .map(|i| create_test_point(i as f64, 0.0, 0.0, 0xFFFFFFFF))
            .collect();
        let result = limit_points(&points, 50);
        assert_eq!(result.len(), 50);
    }

    #[test]
    fn test_pipeline_all_disabled() {
        let points = vec![
            create_test_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_test_point(1.0, 0.0, 0.0, 0xFF00FF00),
        ];
        let config = OptimizationConfig::default();
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_pipeline_dedup_only() {
        let points = vec![
            create_test_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_test_point(0.0, 0.0, 0.0, 0xFF00FF00),
            create_test_point(1.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let config = OptimizationConfig {
            enable_deduplication: true,
            dedup_precision: 0.001,
            ..Default::default()
        };
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 2);
    }
}
