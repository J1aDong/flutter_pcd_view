mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
mod api;
mod parser;
pub mod optimization;
pub mod processing;
pub mod renderer;

pub use api::*;
pub use parser::{parse_pcd_file, Point3D};
pub use optimization::{OptimizationConfig, optimize_points, optimize_points_with_stats};
pub use processing::{ProcessingConfig, ProcessingStats, process_points, process_points_with_stats};
