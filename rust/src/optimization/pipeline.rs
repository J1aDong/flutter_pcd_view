use crate::parser::Point3D;
use super::{deduplicate_points, voxel_grid_downsample, limit_points};

/// Configuration for point cloud optimization.
#[derive(Debug, Clone)]
pub struct OptimizationConfig {
    /// Enable duplicate point removal
    pub enable_deduplication: bool,
    /// Precision for deduplication (grid cell size in meters)
    pub dedup_precision: f64,
    /// Voxel size for downsampling (0 = disabled)
    pub voxel_size: f64,
    /// Maximum number of points (0 = no limit)
    pub max_points: usize,
}

impl Default for OptimizationConfig {
    fn default() -> Self {
        Self {
            enable_deduplication: false,
            dedup_precision: 0.001,
            voxel_size: 0.0,
            max_points: 0,
        }
    }
}

impl OptimizationConfig {
    /// Check if any optimization is enabled
    pub fn is_enabled(&self) -> bool {
        self.enable_deduplication || self.voxel_size > 0.0 || self.max_points > 0
    }
}

/// Result of point cloud optimization with statistics.
#[derive(Debug, Clone)]
pub struct OptimizationResult {
    /// Optimized points
    pub points: Vec<Point3D>,
    /// Original point count
    pub original_count: usize,
    /// Points after deduplication
    pub after_dedup: usize,
    /// Points after voxel grid
    pub after_voxel: usize,
    /// Final point count
    pub final_count: usize,
}

/// Apply the optimization pipeline to a point cloud.
///
/// Pipeline order: Deduplication → Voxel Grid → Max Points
///
/// # Arguments
/// * `points` - Input point cloud
/// * `config` - Optimization configuration
///
/// # Returns
/// Optimized point cloud with statistics
pub fn optimize_points(points: &[Point3D], config: &OptimizationConfig) -> Vec<Point3D> {
    if !config.is_enabled() || points.is_empty() {
        return points.to_vec();
    }

    let mut current = points.to_vec();
    let _original_count = current.len();

    // Step 1: Deduplication
    if config.enable_deduplication {
        current = deduplicate_points(&current, config.dedup_precision);
    }

    // Step 2: Voxel grid downsampling
    if config.voxel_size > 0.0 {
        current = voxel_grid_downsample(&current, config.voxel_size);
    }

    // Step 3: Max points limit
    if config.max_points > 0 {
        current = limit_points(&current, config.max_points);
    }

    current
}

/// Apply optimization pipeline and return detailed statistics.
pub fn optimize_points_with_stats(points: &[Point3D], config: &OptimizationConfig) -> OptimizationResult {
    let original_count = points.len();

    if !config.is_enabled() || points.is_empty() {
        return OptimizationResult {
            points: points.to_vec(),
            original_count,
            after_dedup: original_count,
            after_voxel: original_count,
            final_count: original_count,
        };
    }

    let mut current = points.to_vec();

    // Step 1: Deduplication
    if config.enable_deduplication {
        current = deduplicate_points(&current, config.dedup_precision);
    }
    let after_dedup = current.len();

    // Step 2: Voxel grid downsampling
    if config.voxel_size > 0.0 {
        current = voxel_grid_downsample(&current, config.voxel_size);
    }
    let after_voxel = current.len();

    // Step 3: Max points limit
    if config.max_points > 0 {
        current = limit_points(&current, config.max_points);
    }
    let final_count = current.len();

    OptimizationResult {
        points: current,
        original_count,
        after_dedup,
        after_voxel,
        final_count,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_point(x: f64, y: f64, z: f64, color: u32) -> Point3D {
        Point3D { x, y, z, color, has_color: true }
    }

    #[test]
    fn test_default_config_no_optimization() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(1.0, 0.0, 0.0, 0xFFFFFFFF),
        ];
        let config = OptimizationConfig::default();
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_dedup_only() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_point(0.0, 0.0, 0.0, 0xFF00FF00),
            create_point(1.0, 0.0, 0.0, 0xFF0000FF),
        ];
        let config = OptimizationConfig {
            enable_deduplication: true,
            dedup_precision: 0.001,
            ..Default::default()
        };
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_voxel_only() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(0.1, 0.1, 0.1, 0xFFFFFFFF),
            create_point(2.0, 0.0, 0.0, 0xFFFFFFFF),
        ];
        let config = OptimizationConfig {
            voxel_size: 1.0,
            ..Default::default()
        };
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 2); // 2 voxels
    }

    #[test]
    fn test_max_points_only() {
        let points: Vec<Point3D> = (0..100)
            .map(|i| create_point(i as f64, 0.0, 0.0, 0xFFFFFFFF))
            .collect();
        let config = OptimizationConfig {
            max_points: 50,
            ..Default::default()
        };
        let result = optimize_points(&points, &config);
        assert_eq!(result.len(), 50);
    }

    #[test]
    fn test_full_pipeline() {
        let points: Vec<Point3D> = (0..1000)
            .map(|i| create_point((i % 10) as f64, (i / 10 % 10) as f64, (i / 100) as f64, 0xFFFFFFFF))
            .collect();

        let config = OptimizationConfig {
            enable_deduplication: true,
            dedup_precision: 0.001,
            voxel_size: 0.5,
            max_points: 100,
        };

        let result = optimize_points_with_stats(&points, &config);
        assert_eq!(result.final_count, 100);
        assert!(result.after_dedup <= result.original_count);
        assert!(result.after_voxel <= result.after_dedup);
        assert!(result.final_count <= result.after_voxel);
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let config = OptimizationConfig {
            enable_deduplication: true,
            dedup_precision: 0.001,
            voxel_size: 1.0,
            max_points: 100,
        };
        let result = optimize_points(&points, &config);
        assert!(result.is_empty());
    }

    #[test]
    fn test_stats_no_optimization() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(1.0, 0.0, 0.0, 0xFFFFFFFF),
        ];
        let config = OptimizationConfig::default();
        let result = optimize_points_with_stats(&points, &config);
        assert_eq!(result.original_count, 2);
        assert_eq!(result.after_dedup, 2);
        assert_eq!(result.after_voxel, 2);
        assert_eq!(result.final_count, 2);
    }
}
