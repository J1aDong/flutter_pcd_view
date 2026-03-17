use crate::parser::Point3D;
use std::collections::HashMap;

/// Voxel cell containing accumulated point data for averaging
struct VoxelCell {
    sum_x: f64,
    sum_y: f64,
    sum_z: f64,
    sum_r: f64,
    sum_g: f64,
    sum_b: f64,
    count: u32,
    colored_count: u32,
}

impl VoxelCell {
    fn new() -> Self {
        Self {
            sum_x: 0.0,
            sum_y: 0.0,
            sum_z: 0.0,
            sum_r: 0.0,
            sum_g: 0.0,
            sum_b: 0.0,
            count: 0,
            colored_count: 0,
        }
    }

    fn add_point(&mut self, point: &Point3D) {
        self.sum_x += point.x;
        self.sum_y += point.y;
        self.sum_z += point.z;

        if point.has_color {
            let r = ((point.color >> 16) & 0xFF) as f64;
            let g = ((point.color >> 8) & 0xFF) as f64;
            let b = (point.color & 0xFF) as f64;

            self.sum_r += r;
            self.sum_g += g;
            self.sum_b += b;
            self.colored_count += 1;
        }

        self.count += 1;
    }

    fn to_point(&self) -> Point3D {
        let count = self.count as f64;
        let has_color = self.colored_count > 0;
        let color = if has_color {
            let colored_count = self.colored_count as f64;
            let avg_r = (self.sum_r / colored_count).round() as u32;
            let avg_g = (self.sum_g / colored_count).round() as u32;
            let avg_b = (self.sum_b / colored_count).round() as u32;
            0xFF000000 | (avg_r << 16) | (avg_g << 8) | avg_b
        } else {
            0xFFFFFFFF
        };

        Point3D {
            x: self.sum_x / count,
            y: self.sum_y / count,
            z: self.sum_z / count,
            color,
            has_color,
        }
    }
}

/// Downsample point cloud using voxel grid algorithm.
///
/// Divides space into cubic voxels and replaces all points within each voxel
/// with their centroid. Colors are averaged.
///
/// # Arguments
/// * `points` - Input point cloud
/// * `voxel_size` - Size of each voxel in meters (must be > 0)
///
/// # Returns
/// Downsampled point cloud with one point per occupied voxel
pub fn voxel_grid_downsample(points: &[Point3D], voxel_size: f64) -> Vec<Point3D> {
    if voxel_size <= 0.0 || points.is_empty() {
        return points.to_vec();
    }

    let mut voxels: HashMap<(i64, i64, i64), VoxelCell> = HashMap::new();
    let inv_voxel_size = 1.0 / voxel_size;

    for point in points {
        let key = (
            (point.x * inv_voxel_size).floor() as i64,
            (point.y * inv_voxel_size).floor() as i64,
            (point.z * inv_voxel_size).floor() as i64,
        );

        voxels.entry(key).or_insert_with(VoxelCell::new).add_point(point);
    }

    voxels.into_values().map(|cell| cell.to_point()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_point(x: f64, y: f64, z: f64, color: u32) -> Point3D {
        Point3D { x, y, z, color, has_color: true }
    }

    #[test]
    fn test_single_voxel() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFF0000),
            create_point(0.1, 0.1, 0.1, 0xFF00FF00),
            create_point(0.2, 0.2, 0.2, 0xFF0000FF),
        ];
        // All points within 1m voxel
        let result = voxel_grid_downsample(&points, 1.0);
        assert_eq!(result.len(), 1);

        // Check centroid
        let p = &result[0];
        assert!((p.x - 0.1).abs() < 0.01);
        assert!((p.y - 0.1).abs() < 0.01);
        assert!((p.z - 0.1).abs() < 0.01);
    }

    #[test]
    fn test_multiple_voxels() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFFFFFF),
            create_point(1.5, 0.0, 0.0, 0xFFFFFFFF), // Different 1m voxel
        ];
        let result = voxel_grid_downsample(&points, 1.0);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_color_averaging() {
        let points = vec![
            create_point(0.0, 0.0, 0.0, 0xFFFF0000), // Red
            create_point(0.1, 0.1, 0.1, 0xFF0000FF), // Blue
        ];
        let result = voxel_grid_downsample(&points, 1.0);
        assert_eq!(result.len(), 1);

        // Average of red (255,0,0) and blue (0,0,255) = (127,0,127) = purple
        let r = (result[0].color >> 16) & 0xFF;
        let b = result[0].color & 0xFF;
        assert_eq!(r, 128);
        assert_eq!(b, 128);
    }

    #[test]
    fn test_empty_input() {
        let points: Vec<Point3D> = vec![];
        let result = voxel_grid_downsample(&points, 1.0);
        assert!(result.is_empty());
    }

    #[test]
    fn test_invalid_voxel_size() {
        let points = vec![create_point(0.0, 0.0, 0.0, 0xFFFFFFFF)];
        let result = voxel_grid_downsample(&points, 0.0);
        assert_eq!(result.len(), 1);

        let result = voxel_grid_downsample(&points, -1.0);
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn test_preserves_spatial_distribution() {
        // Create a 3x3x3 grid of points
        let mut points = Vec::new();
        for x in 0..3 {
            for y in 0..3 {
                for z in 0..3 {
                    points.push(create_point(x as f64, y as f64, z as f64, 0xFFFFFFFF));
                }
            }
        }
        // 27 points in 1m grid -> 27 voxels
        let result = voxel_grid_downsample(&points, 1.0);
        assert_eq!(result.len(), 27);

        // With 3m voxel, should collapse to 1 point
        let result = voxel_grid_downsample(&points, 3.0);
        assert_eq!(result.len(), 1);
    }
}
