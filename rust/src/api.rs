use crate::parser::{parse_pcd_file, parse_pcd_string, Point3D};

pub fn parse_pcd(path: String) -> Result<Vec<Point3D>, String> {
    parse_pcd_file(path)
}

pub fn parse_pcd_data(content: String) -> Result<Vec<Point3D>, String> {
    parse_pcd_string(content)
}
