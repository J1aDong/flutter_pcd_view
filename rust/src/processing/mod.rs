//! Point cloud processing algorithms
//!
//! This module provides advanced point cloud processing capabilities:
//! - Outlier removal (SOR, ROR)
//! - Point connectivity (sequential, nearest neighbor)
//! - Point cloud merging

mod connectivity;
mod merge;
mod outlier;

pub use connectivity::{ConnectConfig, ConnectMode, connect_points};
pub use merge::{MergeConfig, merge_point_clouds};
pub use outlier::{RORConfig, SORConfig, remove_outliers, remove_outliers_with_stats};

use crate::parser::Point3D;

/// Processing pipeline statistics
#[derive(Debug, Clone, Default)]
pub struct ProcessingStats {
    /// Original point count
    pub original_count: usize,
    /// After SOR removal (if applied)
    pub after_sor: usize,
    /// After ROR removal (if applied)
    pub after_ror: usize,
    /// Final point count after all processing
    pub final_count: usize,
}

/// Processing pipeline configuration
#[derive(Debug, Clone)]
pub struct ProcessingConfig {
    /// Statistical Outlier Removal configuration
    pub sor: Option<SORConfig>,
    /// Radius Outlier Removal configuration
    pub ror: Option<RORConfig>,
    /// Point connectivity configuration
    pub connect: Option<ConnectConfig>,
}

impl Default for ProcessingConfig {
    fn default() -> Self {
        Self {
            sor: None,
            ror: None,
            connect: None,
        }
    }
}

impl ProcessingConfig {
    /// Check if any processing is enabled
    pub fn is_enabled(&self) -> bool {
        self.sor.is_some() || self.ror.is_some() || self.connect.is_some()
    }
}

/// Apply full processing pipeline to points
pub fn process_points(points: &[Point3D], config: &ProcessingConfig) -> Vec<Point3D> {
    let mut result = points.to_vec();

    // Apply SOR first
    if let Some(sor_config) = &config.sor {
        result = remove_outliers(&result, Some(sor_config.clone()), None);
    }

    // Apply ROR second
    if let Some(ror_config) = &config.ror {
        result = remove_outliers(&result, None, Some(ror_config.clone()));
    }

    // Connectivity is handled separately in rendering
    result
}

/// Apply full processing pipeline with statistics
pub fn process_points_with_stats(
    points: &[Point3D],
    config: &ProcessingConfig,
) -> (Vec<Point3D>, ProcessingStats) {
    let original_count = points.len();
    let mut stats = ProcessingStats {
        original_count,
        after_sor: original_count,
        after_ror: original_count,
        final_count: original_count,
    };

    let mut result = points.to_vec();

    // Apply SOR first
    if let Some(sor_config) = &config.sor {
        let (filtered, after_sor) =
            remove_outliers_with_stats(&result, Some(sor_config.clone()), None);
        stats.after_sor = after_sor;
        stats.after_ror = after_sor;
        result = filtered;
    }

    // Apply ROR second
    if let Some(ror_config) = &config.ror {
        let (filtered, after_ror) =
            remove_outliers_with_stats(&result, None, Some(ror_config.clone()));
        stats.after_ror = after_ror;
        result = filtered;
    }

    stats.final_count = result.len();
    (result, stats)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_point(x: f64, y: f64, z: f64) -> Point3D {
        Point3D {
            x,
            y,
            z,
            color: 0xFFFFFFFF,
        }
    }

    #[test]
    fn test_default_config_no_processing() {
        let points = vec![create_point(0.0, 0.0, 0.0), create_point(1.0, 0.0, 0.0)];
        let config = ProcessingConfig::default();
        let result = process_points(&points, &config);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_is_enabled() {
        let config = ProcessingConfig::default();
        assert!(!config.is_enabled());

        let config = ProcessingConfig {
            sor: Some(SORConfig::default()),
            ..Default::default()
        };
        assert!(config.is_enabled());
    }
}
