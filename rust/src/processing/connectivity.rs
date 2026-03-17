//! Point connectivity algorithms for line segment generation
//!
//! Provides two connection modes:
//! - Sequential: Connect points in file order (for LIDAR scan lines)
//! - Nearest Neighbor: Connect points using spatial search

use crate::parser::Point3D;

/// Connection mode
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ConnectMode {
    /// No connection (points only)
    #[default]
    None,
    /// Connect points in file order
    Sequential,
    /// Connect points to nearest neighbors
    NearestNeighbor,
}

/// Connectivity configuration
#[derive(Debug, Clone)]
pub struct ConnectConfig {
    /// Connection mode
    pub mode: ConnectMode,
    /// Maximum distance for nearest neighbor connection
    pub max_distance: f64,
    /// Maximum number of line segments (for sequential mode)
    pub max_segments: usize,
}

impl Default for ConnectConfig {
    fn default() -> Self {
        Self {
            mode: ConnectMode::None,
            max_distance: 0.5,
            max_segments: usize::MAX,
        }
    }
}

/// Line segment representation
#[derive(Debug, Clone)]
pub struct LineSegment {
    pub start: Point3D,
    pub end: Point3D,
}

/// Connect points into line segments
pub fn connect_points(points: &[Point3D], config: &ConnectConfig) -> Vec<LineSegment> {
    match config.mode {
        ConnectMode::None => Vec::new(),
        ConnectMode::Sequential => connect_sequential(points, config.max_segments),
        ConnectMode::NearestNeighbor => connect_nearest_neighbor(points, config.max_distance),
    }
}

/// Connect points in sequential order
fn connect_sequential(points: &[Point3D], max_segments: usize) -> Vec<LineSegment> {
    if points.len() < 2 {
        return Vec::new();
    }

    let segment_count = (points.len() - 1).min(max_segments);
    (0..segment_count)
        .map(|i| LineSegment {
            start: points[i].clone(),
            end: points[i + 1].clone(),
        })
        .collect()
}

/// Calculate squared distance between two points
fn distance_sq(p1: &Point3D, p2: &Point3D) -> f64 {
    let dx = p2.x - p1.x;
    let dy = p2.y - p1.y;
    let dz = p2.z - p1.z;
    dx * dx + dy * dy + dz * dz
}

/// Find nearest neighbor for a point (excluding self)
fn find_nearest_neighbor(
    points: &[Point3D],
    query_idx: usize,
    max_distance: f64,
) -> Option<(usize, f64)> {
    let query = &points[query_idx];
    let max_dist_sq = max_distance * max_distance;

    points
        .iter()
        .enumerate()
        .filter(|(i, _)| *i != query_idx)
        .map(|(i, p)| (i, distance_sq(query, p)))
        .filter(|(_, d)| *d <= max_dist_sq)
        .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
}

/// Connect points to their nearest neighbors
fn connect_nearest_neighbor(points: &[Point3D], max_distance: f64) -> Vec<LineSegment> {
    if points.len() < 2 {
        return Vec::new();
    }

    let mut connected = vec![false; points.len()];
    let mut segments = Vec::new();

    for (i, point) in points.iter().enumerate() {
        if connected[i] {
            continue;
        }

        // Find nearest neighbor within max distance
        if let Some((j, _)) = find_nearest_neighbor(points, i, max_distance) {
            if !connected[j] {
                segments.push(LineSegment {
                    start: point.clone(),
                    end: points[j].clone(),
                });
                connected[i] = true;
                connected[j] = true;
            }
        }
    }

    segments
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
            has_color: false,
        }
    }

    #[test]
    fn test_none_mode_no_segments() {
        let points = vec![create_point(0.0, 0.0, 0.0), create_point(1.0, 0.0, 0.0)];
        let config = ConnectConfig {
            mode: ConnectMode::None,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert!(segments.is_empty());
    }

    #[test]
    fn test_sequential_mode() {
        let points = vec![
            create_point(0.0, 0.0, 0.0),
            create_point(1.0, 0.0, 0.0),
            create_point(2.0, 0.0, 0.0),
        ];
        let config = ConnectConfig {
            mode: ConnectMode::Sequential,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert_eq!(segments.len(), 2);
        assert!((segments[0].start.x - 0.0).abs() < 0.001);
        assert!((segments[0].end.x - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_sequential_max_segments() {
        let points: Vec<Point3D> = (0..10).map(|i| create_point(i as f64, 0.0, 0.0)).collect();
        let config = ConnectConfig {
            mode: ConnectMode::Sequential,
            max_segments: 3,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert_eq!(segments.len(), 3);
    }

    #[test]
    fn test_nearest_neighbor_mode() {
        // Create a chain of nearby points
        let points = vec![
            create_point(0.0, 0.0, 0.0),
            create_point(0.1, 0.0, 0.0),
            create_point(0.2, 0.0, 0.0),
        ];
        let config = ConnectConfig {
            mode: ConnectMode::NearestNeighbor,
            max_distance: 0.15,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert!(!segments.is_empty());
    }

    #[test]
    fn test_nearest_neighbor_respects_max_distance() {
        // Points too far apart
        let points = vec![create_point(0.0, 0.0, 0.0), create_point(10.0, 0.0, 0.0)];
        let config = ConnectConfig {
            mode: ConnectMode::NearestNeighbor,
            max_distance: 1.0,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert!(segments.is_empty());
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let config = ConnectConfig {
            mode: ConnectMode::Sequential,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert!(segments.is_empty());
    }

    #[test]
    fn test_single_point() {
        let points = vec![create_point(0.0, 0.0, 0.0)];
        let config = ConnectConfig {
            mode: ConnectMode::Sequential,
            ..Default::default()
        };
        let segments = connect_points(&points, &config);
        assert!(segments.is_empty());
    }
}
