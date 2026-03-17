//! Point cloud merging algorithms
//!
//! Provides functionality to merge multiple point clouds with optional
//! source color assignment for visualization.

use crate::parser::Point3D;

/// Merge configuration
#[derive(Debug, Clone, Default)]
pub struct MergeConfig {
    /// Automatically assign distinct colors to each source
    pub auto_color: bool,
    /// Custom colors for each source (ARGB format)
    pub source_colors: Vec<u32>,
}

/// Result of point cloud merge operation
#[derive(Debug, Clone)]
pub struct MergeResult {
    /// Merged points
    pub points: Vec<Point3D>,
    /// Point count per source
    pub source_counts: Vec<usize>,
}

/// Merge multiple point clouds into one
pub fn merge_point_clouds(sources: &[Vec<Point3D>], config: &MergeConfig) -> MergeResult {
    if sources.is_empty() {
        return MergeResult {
            points: Vec::new(),
            source_counts: Vec::new(),
        };
    }

    let source_counts: Vec<usize> = sources.iter().map(|s| s.len()).collect();
    let total_points: usize = source_counts.iter().sum();

    if total_points == 0 {
        return MergeResult {
            points: Vec::new(),
            source_counts,
        };
    }

    // Pre-generate colors for each source
    let colors = if let Some(custom_colors) = config.source_colors.first() {
        // Use custom colors if provided
        if config.source_colors.len() >= sources.len() {
            config.source_colors.clone()
        } else {
            // Pad with generated colors
            let mut colors = config.source_colors.clone();
            colors.extend(generate_distinct_colors(sources.len() - colors.len()));
            colors
        }
    } else if config.auto_color {
        generate_distinct_colors(sources.len())
    } else {
        Vec::new()
    };

    let mut merged = Vec::with_capacity(total_points);

    for (source_idx, points) in sources.iter().enumerate() {
        let color = colors.get(source_idx).copied();
        for point in points {
            merged.push(Point3D {
                x: point.x,
                y: point.y,
                z: point.z,
                color: color.unwrap_or(point.color),
                has_color: color.is_some() || point.has_color,
            });
        }
    }

    MergeResult {
        points: merged,
        source_counts,
    }
}

/// Generate visually distinct colors for sources
fn generate_distinct_colors(n: usize) -> Vec<u32> {
    if n == 0 {
        return Vec::new();
    }

    // Use golden ratio for color distribution
    let golden_ratio: f64 = 0.618033988749895;
    let mut colors = Vec::with_capacity(n);
    let mut hue = 0.0;

    for _ in 0..n {
        hue = (hue + golden_ratio) % 1.0;
        let (r, g, b) = hsv_to_rgb(hue, 0.8, 0.9);
        colors.push(argb_to_u32(255, r, g, b));
    }

    colors
}

/// Convert HSV to RGB
fn hsv_to_rgb(h: f64, s: f64, v: f64) -> (u8, u8, u8) {
    let h_i = (h * 6.0) as i32 % 6;
    let f = h * 6.0 - (h * 6.0).floor();
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);

    let (r, g, b) = match h_i {
        0 => (v, t, p),
        1 => (q, v, p),
        2 => (p, v, t),
        3 => (p, q, v),
        4 => (t, p, v),
        _ => (v, p, q),
    };

    ((r * 255.0) as u8, (g * 255.0) as u8, (b * 255.0) as u8)
}

/// Convert ARGB components to u32
fn argb_to_u32(a: u8, r: u8, g: u8, b: u8) -> u32 {
    ((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
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
    fn test_empty_sources() {
        let sources: Vec<Vec<Point3D>> = vec![];
        let config = MergeConfig::default();
        let result = merge_point_clouds(&sources, &config);
        assert!(result.points.is_empty());
        assert!(result.source_counts.is_empty());
    }

    #[test]
    fn test_single_source() {
        let points = vec![create_point(0.0, 0.0, 0.0), create_point(1.0, 0.0, 0.0)];
        let sources = vec![points.clone()];
        let config = MergeConfig::default();
        let result = merge_point_clouds(&sources, &config);
        assert_eq!(result.points.len(), 2);
        assert_eq!(result.source_counts, vec![2]);
    }

    #[test]
    fn test_multiple_sources() {
        let source1 = vec![create_point(0.0, 0.0, 0.0)];
        let source2 = vec![create_point(1.0, 0.0, 0.0), create_point(2.0, 0.0, 0.0)];
        let sources = vec![source1, source2];
        let config = MergeConfig::default();
        let result = merge_point_clouds(&sources, &config);
        assert_eq!(result.points.len(), 3);
        assert_eq!(result.source_counts, vec![1, 2]);
    }

    #[test]
    fn test_auto_color() {
        let source1 = vec![create_point(0.0, 0.0, 0.0)];
        let source2 = vec![create_point(1.0, 0.0, 0.0)];
        let sources = vec![source1, source2];
        let config = MergeConfig {
            auto_color: true,
            ..Default::default()
        };
        let result = merge_point_clouds(&sources, &config);
        assert_eq!(result.points.len(), 2);
        // Colors should be different
        assert_ne!(result.points[0].color, result.points[1].color);
    }

    #[test]
    fn test_custom_colors() {
        let source1 = vec![create_point(0.0, 0.0, 0.0)];
        let source2 = vec![create_point(1.0, 0.0, 0.0)];
        let sources = vec![source1, source2];
        let config = MergeConfig {
            auto_color: false,
            source_colors: vec![0xFFFF0000, 0xFF00FF00], // Red, Green
        };
        let result = merge_point_clouds(&sources, &config);
        assert_eq!(result.points[0].color, 0xFFFF0000);
        assert_eq!(result.points[1].color, 0xFF00FF00);
    }

    #[test]
    fn test_preserves_coordinates() {
        let source1 = vec![create_point(1.5, 2.5, 3.5)];
        let source2 = vec![create_point(4.5, 5.5, 6.5)];
        let sources = vec![source1, source2];
        let config = MergeConfig::default();
        let result = merge_point_clouds(&sources, &config);

        assert!((result.points[0].x - 1.5).abs() < 0.001);
        assert!((result.points[0].y - 2.5).abs() < 0.001);
        assert!((result.points[0].z - 3.5).abs() < 0.001);
        assert!((result.points[1].x - 4.5).abs() < 0.001);
        assert!((result.points[1].y - 5.5).abs() < 0.001);
        assert!((result.points[1].z - 6.5).abs() < 0.001);
    }

    #[test]
    fn test_empty_point_clouds() {
        let source1: Vec<Point3D> = vec![];
        let source2 = vec![create_point(1.0, 0.0, 0.0)];
        let sources = vec![source1, source2];
        let config = MergeConfig::default();
        let result = merge_point_clouds(&sources, &config);
        assert_eq!(result.points.len(), 1);
        assert_eq!(result.source_counts, vec![0, 1]);
    }

    #[test]
    fn test_generate_distinct_colors() {
        let colors = generate_distinct_colors(5);
        assert_eq!(colors.len(), 5);
        // All colors should be distinct
        let unique: std::collections::HashSet<u32> = colors.iter().copied().collect();
        assert_eq!(unique.len(), 5);
    }
}