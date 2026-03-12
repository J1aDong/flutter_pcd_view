//! Outlier removal algorithms for point cloud processing
//!
//! Implements two industry-standard outlier removal methods:
//! - SOR (Statistical Outlier Removal): Removes points based on local density statistics
//! - ROR (Radius Outlier Removal): Removes points with too few neighbors in a given radius

use crate::parser::Point3D;

/// Statistical Outlier Removal configuration
#[derive(Debug, Clone)]
pub struct SORConfig {
    /// Number of nearest neighbors to consider
    pub k: usize,
    /// Standard deviation multiplier threshold
    pub std_ratio: f64,
}

impl Default for SORConfig {
    fn default() -> Self {
        Self {
            k: 50,
            std_ratio: 1.0,
        }
    }
}

/// Radius Outlier Removal configuration
#[derive(Debug, Clone)]
pub struct RORConfig {
    /// Search radius
    pub radius: f64,
    /// Minimum number of neighbors required
    pub min_neighbors: usize,
}

impl Default for RORConfig {
    fn default() -> Self {
        Self {
            radius: 0.1,
            min_neighbors: 5,
        }
    }
}

/// Calculate squared distance between two points
fn distance_sq(p1: &Point3D, p2: &Point3D) -> f64 {
    let dx = p2.x - p1.x;
    let dy = p2.y - p1.y;
    let dz = p2.z - p1.z;
    dx * dx + dy * dy + dz * dz
}

/// Find k nearest neighbors for a point
fn find_k_nearest(points: &[Point3D], query_idx: usize, k: usize) -> Vec<(usize, f64)> {
    let query = &points[query_idx];
    let mut distances: Vec<(usize, f64)> = points
        .iter()
        .enumerate()
        .filter(|(i, _)| *i != query_idx)
        .map(|(i, p)| (i, distance_sq(query, p)))
        .collect();

    distances.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
    distances.truncate(k);
    distances
}

/// Count neighbors within radius
fn count_neighbors_in_radius(points: &[Point3D], query_idx: usize, radius: f64) -> usize {
    let query = &points[query_idx];
    let radius_sq = radius * radius;
    points
        .iter()
        .enumerate()
        .filter(|(i, p)| {
            *i != query_idx && distance_sq(query, p) <= radius_sq
        })
        .count()
}

/// Remove outliers using SOR and/or ROR
pub fn remove_outliers(
    points: &[Point3D],
    sor_config: Option<SORConfig>,
    ror_config: Option<RORConfig>,
) -> Vec<Point3D> {
    let (result, _) = remove_outliers_with_stats(points, sor_config, ror_config);
    result
}

/// Remove outliers with statistics
pub fn remove_outliers_with_stats(
    points: &[Point3D],
    sor_config: Option<SORConfig>,
    ror_config: Option<RORConfig>,
) -> (Vec<Point3D>, usize) {
    if points.is_empty() {
        return (Vec::new(), 0);
    }

    if sor_config.is_none() && ror_config.is_none() {
        return (points.to_vec(), points.len());
    }

    let mut current_points = points.to_vec();
    let mut current_count = points.len();

    // Apply SOR first
    if let Some(config) = sor_config {
        let sor_indices = apply_sor(&current_points, &config);
        current_points = sor_indices.iter().map(|&i| current_points[i].clone()).collect();
        current_count = current_points.len();
    }

    // Apply ROR
    if let Some(config) = ror_config {
        if !current_points.is_empty() {
            let ror_indices = apply_ror(&current_points, &config);
            current_points = ror_indices.iter().map(|&i| current_points[i].clone()).collect();
            current_count = current_points.len();
        }
    }

    (current_points, current_count)
}

/// Apply Statistical Outlier Removal
fn apply_sor(points: &[Point3D], config: &SORConfig) -> Vec<usize> {
    if points.len() < 2 {
        return (0..points.len()).collect();
    }

    let k = config.k.min(points.len() - 1).max(1);

    // Calculate average distances for each point
    let avg_distances: Vec<f64> = (0..points.len())
        .map(|i| {
            let neighbors = find_k_nearest(points, i, k);
            if neighbors.is_empty() {
                0.0
            } else {
                neighbors.iter().map(|(_, d)| d.sqrt()).sum::<f64>() / neighbors.len() as f64
            }
        })
        .collect();

    // Calculate mean and std deviation
    let n = avg_distances.len() as f64;
    let mean = avg_distances.iter().sum::<f64>() / n;
    let variance = avg_distances.iter().map(|d| (d - mean).powi(2)).sum::<f64>() / n;
    let std = variance.sqrt();

    let threshold = mean + config.std_ratio * std;

    // Keep points within threshold
    (0..points.len())
        .filter(|&i| avg_distances[i] <= threshold)
        .collect()
}

/// Apply Radius Outlier Removal
fn apply_ror(points: &[Point3D], config: &RORConfig) -> Vec<usize> {
    if points.is_empty() {
        return Vec::new();
    }

    (0..points.len())
        .filter(|&i| {
            let count = count_neighbors_in_radius(points, i, config.radius);
            count >= config.min_neighbors
        })
        .collect()
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
    fn test_sor_removes_outliers() {
        // Create a dense cluster and one outlier
        let mut points: Vec<Point3D> = (0..100)
            .map(|i| create_point(i as f64 * 0.01, 0.0, 0.0))
            .collect();
        // Add an outlier far away
        points.push(create_point(100.0, 100.0, 100.0));

        let config = SORConfig {
            k: 10,
            std_ratio: 1.0,
        };
        let result = remove_outliers(&points, Some(config), None);
        assert!(result.len() < points.len());
    }

    #[test]
    fn test_ror_removes_isolated_points() {
        // Create a dense cluster
        let mut points: Vec<Point3D> = (0..50)
            .map(|i| create_point(i as f64 * 0.01, 0.0, 0.0))
            .collect();
        // Add isolated points
        points.push(create_point(10.0, 10.0, 10.0));
        points.push(create_point(20.0, 20.0, 20.0));

        let config = RORConfig {
            radius: 0.1,
            min_neighbors: 5,
        };
        let result = remove_outliers(&points, None, Some(config));
        assert!(result.len() < points.len());
    }

    #[test]
    fn test_no_removal_when_disabled() {
        let points = vec![create_point(0.0, 0.0, 0.0), create_point(1.0, 0.0, 0.0)];
        let result = remove_outliers(&points, None, None);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let config = SORConfig::default();
        let result = remove_outliers(&points, Some(config), None);
        assert!(result.is_empty());
    }

    #[test]
    fn test_combined_sor_ror() {
        let mut points: Vec<Point3D> = (0..100)
            .map(|i| create_point(i as f64 * 0.01, 0.0, 0.0))
            .collect();
        points.push(create_point(100.0, 100.0, 100.0)); // SOR outlier
        points.push(create_point(50.0, 50.0, 50.0)); // ROR outlier

        let sor_config = SORConfig {
            k: 10,
            std_ratio: 1.0,
        };
        let ror_config = RORConfig {
            radius: 0.1,
            min_neighbors: 3,
        };
        let result = remove_outliers(&points, Some(sor_config), Some(ror_config));
        assert!(result.len() < points.len());
    }

    #[test]
    fn test_stats_tracking() {
        let points: Vec<Point3D> = (0..10).map(|i| create_point(i as f64, 0.0, 0.0)).collect();
        let (result, count) = remove_outliers_with_stats(&points, None, None);
        assert_eq!(count, 10);
        assert_eq!(result.len(), 10);
    }
}