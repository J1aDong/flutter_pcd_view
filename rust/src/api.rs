use crate::parser::{parse_pcd_file, parse_pcd_string, Point3D};
use crate::optimization::{optimize_points_with_stats, OptimizationConfig as RustOptimizationConfig};
use crate::processing::{
    process_points_with_stats, connect_points, ConnectConfig, ConnectMode,
    ProcessingConfig as RustProcessingConfig, RORConfig, SORConfig,
};

/// Optimization configuration for point cloud processing.
/// All fields have sensible defaults that preserve original behavior.
pub struct OptimizationOptions {
    /// Enable duplicate point removal using spatial hashing
    pub enable_deduplication: bool,
    /// Precision for deduplication (grid cell size in meters)
    pub dedup_precision: f64,
    /// Voxel size for downsampling (0 = disabled)
    pub voxel_size: f64,
    /// Maximum number of points (0 = no limit)
    pub max_points: i32,
}

impl Default for OptimizationOptions {
    fn default() -> Self {
        Self {
            enable_deduplication: false,
            dedup_precision: 0.001,
            voxel_size: 0.0,
            max_points: 0,
        }
    }
}

/// Statistical Outlier Removal configuration
pub struct SOROptions {
    /// Number of nearest neighbors to consider
    pub k: i32,
    /// Standard deviation multiplier threshold
    pub std_ratio: f64,
}

impl Default for SOROptions {
    fn default() -> Self {
        Self {
            k: 50,
            std_ratio: 1.0,
        }
    }
}

/// Radius Outlier Removal configuration
pub struct ROROptions {
    /// Search radius in meters
    pub radius: f64,
    /// Minimum number of neighbors required
    pub min_neighbors: i32,
}

impl Default for ROROptions {
    fn default() -> Self {
        Self {
            radius: 0.1,
            min_neighbors: 5,
        }
    }
}

/// Connectivity mode for line generation
pub enum ConnectModeType {
    /// No connection (points only)
    None,
    /// Connect points in file order
    Sequential,
    /// Connect points to nearest neighbors
    NearestNeighbor,
}

impl Default for ConnectModeType {
    fn default() -> Self {
        Self::None
    }
}

/// Connectivity configuration for line segment generation
pub struct ConnectOptions {
    /// Connection mode
    pub mode: ConnectModeType,
    /// Maximum distance for nearest neighbor connection
    pub max_distance: f64,
    /// Maximum number of line segments (for sequential mode)
    pub max_segments: i32,
}

impl Default for ConnectOptions {
    fn default() -> Self {
        Self {
            mode: ConnectModeType::None,
            max_distance: 0.5,
            max_segments: 100000,
        }
    }
}

/// Processing configuration for advanced point cloud operations
pub struct ProcessingOptions {
    /// Statistical Outlier Removal configuration
    pub sor: Option<SOROptions>,
    /// Radius Outlier Removal configuration
    pub ror: Option<ROROptions>,
    /// Connectivity configuration
    pub connect: Option<ConnectOptions>,
}

impl Default for ProcessingOptions {
    fn default() -> Self {
        Self {
            sor: None,
            ror: None,
            connect: None,
        }
    }
}

/// Result of point cloud parsing with optimization statistics.
pub struct ParseResult {
    /// Parsed points
    pub points: Vec<Point3D>,
    /// Original point count
    pub original_count: i32,
    /// Final point count after optimization
    pub final_count: i32,
}

/// Line segment for connectivity visualization
pub struct LineSegmentData {
    /// Start point
    pub start: Point3D,
    /// End point
    pub end: Point3D,
}

/// Result of point cloud parsing with full processing statistics
pub struct ProcessingResult {
    /// Parsed points
    pub points: Vec<Point3D>,
    /// Original point count
    pub original_count: i32,
    /// Point count after SOR (if applied)
    pub after_sor: i32,
    /// Point count after ROR (if applied)
    pub after_ror: i32,
    /// Final point count
    pub final_count: i32,
    /// Line segments from connectivity
    pub line_segments: Vec<LineSegmentData>,
}

/// Parse a PCD file from path with optional optimization.
pub fn parse_pcd(path: String) -> Result<Vec<Point3D>, String> {
    parse_pcd_file(path)
}

/// Parse a PCD file with optimization options.
pub fn parse_pcd_with_optimization(path: String, options: OptimizationOptions) -> Result<ParseResult, String> {
    let points = parse_pcd_file(path)?;

    let config = RustOptimizationConfig {
        enable_deduplication: options.enable_deduplication,
        dedup_precision: options.dedup_precision,
        voxel_size: options.voxel_size,
        max_points: options.max_points as usize,
    };

    let result = optimize_points_with_stats(&points, &config);

    Ok(ParseResult {
        points: result.points,
        original_count: result.original_count as i32,
        final_count: result.final_count as i32,
    })
}

/// Parse a PCD file with full processing options (optimization + SOR/ROR + connectivity)
pub fn parse_pcd_with_processing(
    path: String,
    opt_options: OptimizationOptions,
    proc_options: ProcessingOptions,
) -> Result<ProcessingResult, String> {
    let points = parse_pcd_file(path)?;

    // Apply optimization first
    let opt_config = RustOptimizationConfig {
        enable_deduplication: opt_options.enable_deduplication,
        dedup_precision: opt_options.dedup_precision,
        voxel_size: opt_options.voxel_size,
        max_points: opt_options.max_points as usize,
    };

    let opt_result = optimize_points_with_stats(&points, &opt_config);
    let current_points = opt_result.points;
    let original_count = opt_result.original_count;

    // Build processing config
    let processing_config = RustProcessingConfig {
        sor: proc_options.sor.as_ref().map(|s| SORConfig {
            k: s.k as usize,
            std_ratio: s.std_ratio,
        }),
        ror: proc_options.ror.as_ref().map(|r| RORConfig {
            radius: r.radius,
            min_neighbors: r.min_neighbors as usize,
        }),
        connect: proc_options.connect.as_ref().map(|c| {
            let mode = match c.mode {
                ConnectModeType::None => ConnectMode::None,
                ConnectModeType::Sequential => ConnectMode::Sequential,
                ConnectModeType::NearestNeighbor => ConnectMode::NearestNeighbor,
            };
            ConnectConfig {
                mode,
                max_distance: c.max_distance,
                max_segments: c.max_segments as usize,
            }
        }),
    };

    // Apply processing (SOR, ROR)
    let (processed_points, stats) = process_points_with_stats(&current_points, &processing_config);

    // Generate line segments if connectivity is enabled
    let line_segments = if let Some(connect_config) = &processing_config.connect {
        connect_points(&processed_points, connect_config)
            .into_iter()
            .map(|seg| LineSegmentData {
                start: seg.start,
                end: seg.end,
            })
            .collect()
    } else {
        Vec::new()
    };

    Ok(ProcessingResult {
        points: processed_points,
        original_count: original_count as i32,
        after_sor: stats.after_sor as i32,
        after_ror: stats.after_ror as i32,
        final_count: stats.final_count as i32,
        line_segments,
    })
}

/// Parse PCD content from string (ASCII format only).
pub fn parse_pcd_data(content: String) -> Result<Vec<Point3D>, String> {
    parse_pcd_string(content)
}

/// Parse PCD content from string with optimization options.
pub fn parse_pcd_data_with_optimization(content: String, options: OptimizationOptions) -> Result<ParseResult, String> {
    let points = parse_pcd_string(content)?;

    let config = RustOptimizationConfig {
        enable_deduplication: options.enable_deduplication,
        dedup_precision: options.dedup_precision,
        voxel_size: options.voxel_size,
        max_points: options.max_points as usize,
    };

    let result = optimize_points_with_stats(&points, &config);

    Ok(ParseResult {
        points: result.points,
        original_count: result.original_count as i32,
        final_count: result.final_count as i32,
    })
}

/// Parse PCD content from string with full processing options
pub fn parse_pcd_data_with_processing(
    content: String,
    opt_options: OptimizationOptions,
    proc_options: ProcessingOptions,
) -> Result<ProcessingResult, String> {
    let points = parse_pcd_string(content)?;

    // Apply optimization first
    let opt_config = RustOptimizationConfig {
        enable_deduplication: opt_options.enable_deduplication,
        dedup_precision: opt_options.dedup_precision,
        voxel_size: opt_options.voxel_size,
        max_points: opt_options.max_points as usize,
    };

    let opt_result = optimize_points_with_stats(&points, &opt_config);
    let current_points = opt_result.points;
    let original_count = opt_result.original_count;

    // Build processing config
    let processing_config = RustProcessingConfig {
        sor: proc_options.sor.as_ref().map(|s| SORConfig {
            k: s.k as usize,
            std_ratio: s.std_ratio,
        }),
        ror: proc_options.ror.as_ref().map(|r| RORConfig {
            radius: r.radius,
            min_neighbors: r.min_neighbors as usize,
        }),
        connect: proc_options.connect.as_ref().map(|c| {
            let mode = match c.mode {
                ConnectModeType::None => ConnectMode::None,
                ConnectModeType::Sequential => ConnectMode::Sequential,
                ConnectModeType::NearestNeighbor => ConnectMode::NearestNeighbor,
            };
            ConnectConfig {
                mode,
                max_distance: c.max_distance,
                max_segments: c.max_segments as usize,
            }
        }),
    };

    // Apply processing (SOR, ROR)
    let (processed_points, stats) = process_points_with_stats(&current_points, &processing_config);

    // Generate line segments if connectivity is enabled
    let line_segments = if let Some(connect_config) = &processing_config.connect {
        connect_points(&processed_points, connect_config)
            .into_iter()
            .map(|seg| LineSegmentData {
                start: seg.start,
                end: seg.end,
            })
            .collect()
    } else {
        Vec::new()
    };

    Ok(ProcessingResult {
        points: processed_points,
        original_count: original_count as i32,
        after_sor: stats.after_sor as i32,
        after_ror: stats.after_ror as i32,
        final_count: stats.final_count as i32,
        line_segments,
    })
}
