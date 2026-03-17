use std::fs::File;
use std::io::{BufRead, BufReader, Cursor, Read, Seek, SeekFrom};

#[derive(Debug, Clone)]
pub struct Point3D {
    pub x: f64,
    pub y: f64,
    pub z: f64,
    pub color: u32, // ARGB format: 0xAARRGGBB
    pub has_color: bool,
}

#[derive(Debug, PartialEq)]
enum FieldType {
    XYZ,
    XYZRGB,
    XYZHSV,
}

#[derive(Debug)]
struct PcdHeader {
    version: String,
    fields: Vec<String>,
    size: Vec<usize>,
    type_: Vec<String>,
    count: Vec<usize>,
    width: usize,
    height: usize,
    points: usize,
    data: String, // "ascii" or "binary"
    field_type: FieldType,
}

impl PcdHeader {
    fn new() -> Self {
        PcdHeader {
            version: String::new(),
            fields: Vec::new(),
            size: Vec::new(),
            type_: Vec::new(),
            count: Vec::new(),
            width: 0,
            height: 0,
            points: 0,
            data: String::new(),
            field_type: FieldType::XYZ,
        }
    }

    fn detect_field_type(&mut self) -> Result<(), String> {
        let has_x = self.fields.contains(&"x".to_string());
        let has_y = self.fields.contains(&"y".to_string());
        let has_z = self.fields.contains(&"z".to_string());
        let has_rgb = self.fields.contains(&"rgb".to_string());
        let has_rgba = self.fields.contains(&"rgba".to_string());
        let has_h = self.fields.contains(&"h".to_string());
        let has_s = self.fields.contains(&"s".to_string());
        let has_v = self.fields.contains(&"v".to_string());

        if !has_x || !has_y || !has_z {
            return Err("PCD file must contain x, y, z fields".to_string());
        }

        if has_rgb || has_rgba {
            self.field_type = FieldType::XYZRGB;
        } else if has_h && has_s && has_v {
            self.field_type = FieldType::XYZHSV;
        } else {
            self.field_type = FieldType::XYZ;
        }

        Ok(())
    }

    fn validate(&self) -> Result<(), String> {
        if self.version.is_empty() {
            return Err("Missing VERSION field".to_string());
        }

        if self.fields.is_empty() {
            return Err("Missing FIELDS definition".to_string());
        }

        if self.size.is_empty() {
            return Err("Missing SIZE definition".to_string());
        }

        if self.type_.is_empty() {
            return Err("Missing TYPE definition".to_string());
        }

        if self.count.is_empty() {
            return Err("Missing COUNT definition".to_string());
        }

        if self.fields.len() != self.size.len()
            || self.fields.len() != self.type_.len()
            || self.fields.len() != self.count.len() {
            return Err("FIELDS, SIZE, TYPE, and COUNT must have the same length".to_string());
        }

        if self.width == 0 {
            return Err("WIDTH must be greater than 0".to_string());
        }

        if self.height == 0 {
            return Err("HEIGHT must be greater than 0".to_string());
        }

        if self.points == 0 {
            return Err("POINTS must be greater than 0".to_string());
        }

        if self.width * self.height != self.points {
            return Err(format!(
                "WIDTH * HEIGHT ({} * {}) must equal POINTS ({})",
                self.width, self.height, self.points
            ));
        }

        if self.data.is_empty() {
            return Err("Missing DATA field".to_string());
        }

        let data_lower = self.data.to_lowercase();
        if data_lower != "ascii" && data_lower != "binary" {
            return Err(format!("Unsupported DATA format: {}", self.data));
        }

        for type_str in &self.type_ {
            if !["F", "U", "I"].contains(&type_str.as_str()) {
                return Err(format!("Unsupported TYPE: {}", type_str));
            }
        }

        Ok(())
    }
}

fn parse_header(reader: &mut BufReader<File>) -> Result<(PcdHeader, u64), String> {
    let mut header = PcdHeader::new();
    let mut line = String::new();
    let mut header_bytes = 0u64;

    loop {
        line.clear();
        let bytes_read = reader.read_line(&mut line).map_err(|e| e.to_string())?;

        // Check for EOF
        if bytes_read == 0 {
            return Err("Unexpected end of file while parsing header".to_string());
        }

        header_bytes += bytes_read as u64;

        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }

        match parts[0] {
            "VERSION" => {
                header.version = parts.get(1).ok_or("Missing VERSION value")?.to_string();
            }
            "FIELDS" => {
                header.fields = parts[1..].iter().map(|s| s.to_string()).collect();
            }
            "SIZE" => {
                header.size = parts[1..]
                    .iter()
                    .map(|s| s.parse().map_err(|_| format!("Invalid SIZE: {}", s)))
                    .collect::<Result<Vec<_>, _>>()?;
            }
            "TYPE" => {
                header.type_ = parts[1..].iter().map(|s| s.to_string()).collect();
            }
            "COUNT" => {
                header.count = parts[1..]
                    .iter()
                    .map(|s| s.parse().map_err(|_| format!("Invalid COUNT: {}", s)))
                    .collect::<Result<Vec<_>, _>>()?;
            }
            "WIDTH" => {
                header.width = parts.get(1)
                    .ok_or("Missing WIDTH value")?
                    .parse()
                    .map_err(|_| "Invalid WIDTH")?;
            }
            "HEIGHT" => {
                header.height = parts.get(1)
                    .ok_or("Missing HEIGHT value")?
                    .parse()
                    .map_err(|_| "Invalid HEIGHT")?;
            }
            "POINTS" => {
                header.points = parts.get(1)
                    .ok_or("Missing POINTS value")?
                    .parse()
                    .map_err(|_| "Invalid POINTS")?;
            }
            "DATA" => {
                header.data = parts.get(1).ok_or("Missing DATA value")?.to_string();
                break; // DATA is the last header field
            }
            _ => {}
        }
    }

    header.detect_field_type()?;
    header.validate()?;

    Ok((header, header_bytes))
}

fn parse_ascii_data(reader: &mut BufReader<File>, header: &PcdHeader) -> Result<Vec<Point3D>, String> {
    let mut points = Vec::with_capacity(header.points);
    let mut line = String::new();

    let x_idx = header.fields.iter().position(|f| f == "x").ok_or("Missing x field")?;
    let y_idx = header.fields.iter().position(|f| f == "y").ok_or("Missing y field")?;
    let z_idx = header.fields.iter().position(|f| f == "z").ok_or("Missing z field")?;

    let rgb_idx = header.fields.iter().position(|f| f == "rgb" || f == "rgba");
    let h_idx = header.fields.iter().position(|f| f == "h");
    let s_idx = header.fields.iter().position(|f| f == "s");
    let v_idx = header.fields.iter().position(|f| f == "v");

    for _ in 0..header.points {
        line.clear();
        let bytes_read = reader.read_line(&mut line).map_err(|e| e.to_string())?;
        if bytes_read == 0 {
            break;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let values: Vec<&str> = trimmed.split_whitespace().collect();
        if values.len() < header.fields.len() {
            continue;
        }

        let x = values[x_idx].parse::<f64>().map_err(|_| "Invalid x value")?;
        let y = values[y_idx].parse::<f64>().map_err(|_| "Invalid y value")?;
        let z = values[z_idx].parse::<f64>().map_err(|_| "Invalid z value")?;

        let has_color = !matches!(header.field_type, FieldType::XYZ);
        let color = match header.field_type {
            FieldType::XYZRGB => {
                if let Some(idx) = rgb_idx {
                    let rgb_val = values[idx].parse::<u32>().unwrap_or(0xFFFFFFFF);
                    0xFF000000 | rgb_val // Add alpha channel
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZHSV => {
                if let (Some(h_i), Some(s_i), Some(v_i)) = (h_idx, s_idx, v_idx) {
                    let h = values[h_i].parse::<f64>().unwrap_or(0.0);
                    let s = values[s_i].parse::<f64>().unwrap_or(0.0);
                    let v = values[v_i].parse::<f64>().unwrap_or(0.0);
                    hsv_to_rgb(h, s, v)
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZ => 0xFFFFFFFF,
        };

        points.push(Point3D { x, y, z, color, has_color });
    }

    Ok(points)
}

fn hsv_to_rgb(h: f64, s: f64, v: f64) -> u32 {
    let c = v * s;
    let h_prime = h / 60.0;
    let x = c * (1.0 - ((h_prime % 2.0) - 1.0).abs());
    let m = v - c;

    let (r, g, b) = if h_prime < 1.0 {
        (c, x, 0.0)
    } else if h_prime < 2.0 {
        (x, c, 0.0)
    } else if h_prime < 3.0 {
        (0.0, c, x)
    } else if h_prime < 4.0 {
        (0.0, x, c)
    } else if h_prime < 5.0 {
        (x, 0.0, c)
    } else {
        (c, 0.0, x)
    };

    let r = ((r + m) * 255.0) as u32;
    let g = ((g + m) * 255.0) as u32;
    let b = ((b + m) * 255.0) as u32;

    0xFF000000 | (r << 16) | (g << 8) | b
}

fn parse_binary_data(file: &mut File, header: &PcdHeader, header_bytes: u64) -> Result<Vec<Point3D>, String> {
    file.seek(SeekFrom::Start(header_bytes)).map_err(|e| e.to_string())?;

    let mut points = Vec::with_capacity(header.points);

    let x_idx = header.fields.iter().position(|f| f == "x").ok_or("Missing x field")?;
    let y_idx = header.fields.iter().position(|f| f == "y").ok_or("Missing y field")?;
    let z_idx = header.fields.iter().position(|f| f == "z").ok_or("Missing z field")?;

    let rgb_idx = header.fields.iter().position(|f| f == "rgb" || f == "rgba");
    let h_idx = header.fields.iter().position(|f| f == "h");
    let s_idx = header.fields.iter().position(|f| f == "s");
    let v_idx = header.fields.iter().position(|f| f == "v");

    let point_size: usize = header.size.iter().zip(header.count.iter()).map(|(s, c)| s * c).sum();

    for _ in 0..header.points {
        let mut buffer = vec![0u8; point_size];
        file.read_exact(&mut buffer).map_err(|e| format!("Failed to read point data: {}", e))?;

        let mut offset = 0;
        let mut field_values: Vec<f64> = Vec::new();

        for i in 0..header.fields.len() {
            let size = header.size[i];
            let type_str = &header.type_[i];

            let value = match (type_str.as_str(), size) {
                ("F", 4) => {
                    let bytes = [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]];
                    f32::from_le_bytes(bytes) as f64
                }
                ("F", 8) => {
                    let bytes = [
                        buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3],
                        buffer[offset + 4], buffer[offset + 5], buffer[offset + 6], buffer[offset + 7],
                    ];
                    f64::from_le_bytes(bytes)
                }
                ("U", 4) => {
                    let bytes = [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]];
                    u32::from_le_bytes(bytes) as f64
                }
                ("I", 4) => {
                    let bytes = [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]];
                    i32::from_le_bytes(bytes) as f64
                }
                _ => 0.0,
            };

            field_values.push(value);
            offset += size * header.count[i];
        }

        let x = field_values[x_idx];
        let y = field_values[y_idx];
        let z = field_values[z_idx];

        let has_color = !matches!(header.field_type, FieldType::XYZ);
        let color = match header.field_type {
            FieldType::XYZRGB => {
                if let Some(idx) = rgb_idx {
                    let rgb_val = field_values[idx] as u32;
                    0xFF000000 | rgb_val
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZHSV => {
                if let (Some(h_i), Some(s_i), Some(v_i)) = (h_idx, s_idx, v_idx) {
                    let h = field_values[h_i];
                    let s = field_values[s_i];
                    let v = field_values[v_i];
                    hsv_to_rgb(h, s, v)
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZ => 0xFFFFFFFF,
        };

        points.push(Point3D { x, y, z, color, has_color });
    }

    Ok(points)
}

fn decimal_to_argb(rgb_decimal: f64) -> u32 {
    let rgb_val = rgb_decimal as u32;
    0xFF000000 | rgb_val
}

pub fn parse_pcd_file(path: String) -> Result<Vec<Point3D>, String> {
    let file = File::open(&path).map_err(|e| format!("Failed to open file: {}", e))?;
    let mut reader = BufReader::new(file);

    let (header, header_bytes) = parse_header(&mut reader)?;

    if header.data.to_lowercase() == "ascii" {
        parse_ascii_data(&mut reader, &header)
    } else if header.data.to_lowercase() == "binary" {
        let mut file = File::open(&path).map_err(|e| format!("Failed to open file: {}", e))?;
        parse_binary_data(&mut file, &header, header_bytes)
    } else {
        Err(format!("Unsupported data format: {}", header.data))
    }
}

pub fn parse_pcd_string(content: String) -> Result<Vec<Point3D>, String> {
    let cursor = Cursor::new(content.as_bytes());
    let mut reader = BufReader::new(cursor);

    let (header, _header_bytes) = parse_header_generic(&mut reader)?;

    if header.data.to_lowercase() == "ascii" {
        parse_ascii_data_generic(&mut reader, &header)
    } else {
        Err("Binary format not supported for string parsing".to_string())
    }
}

fn parse_header_generic<R: BufRead>(reader: &mut R) -> Result<(PcdHeader, u64), String> {
    let mut header = PcdHeader::new();
    let mut line = String::new();
    let mut header_bytes = 0u64;

    loop {
        line.clear();
        let bytes_read = reader.read_line(&mut line).map_err(|e| e.to_string())?;

        if bytes_read == 0 {
            return Err("Unexpected end of file while parsing header".to_string());
        }

        header_bytes += bytes_read as u64;

        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }

        match parts[0] {
            "VERSION" => {
                header.version = parts.get(1).ok_or("Missing VERSION value")?.to_string();
            }
            "FIELDS" => {
                header.fields = parts[1..].iter().map(|s| s.to_string()).collect();
            }
            "SIZE" => {
                header.size = parts[1..]
                    .iter()
                    .map(|s| s.parse().map_err(|_| format!("Invalid SIZE: {}", s)))
                    .collect::<Result<Vec<_>, _>>()?;
            }
            "TYPE" => {
                header.type_ = parts[1..].iter().map(|s| s.to_string()).collect();
            }
            "COUNT" => {
                header.count = parts[1..]
                    .iter()
                    .map(|s| s.parse().map_err(|_| format!("Invalid COUNT: {}", s)))
                    .collect::<Result<Vec<_>, _>>()?;
            }
            "WIDTH" => {
                header.width = parts.get(1)
                    .ok_or("Missing WIDTH value")?
                    .parse()
                    .map_err(|_| "Invalid WIDTH")?;
            }
            "HEIGHT" => {
                header.height = parts.get(1)
                    .ok_or("Missing HEIGHT value")?
                    .parse()
                    .map_err(|_| "Invalid HEIGHT")?;
            }
            "POINTS" => {
                header.points = parts.get(1)
                    .ok_or("Missing POINTS value")?
                    .parse()
                    .map_err(|_| "Invalid POINTS")?;
            }
            "DATA" => {
                header.data = parts.get(1).ok_or("Missing DATA value")?.to_string();
                break;
            }
            _ => {}
        }
    }

    header.detect_field_type()?;
    header.validate()?;

    Ok((header, header_bytes))
}

fn parse_ascii_data_generic<R: BufRead>(reader: &mut R, header: &PcdHeader) -> Result<Vec<Point3D>, String> {
    let mut points = Vec::with_capacity(header.points);
    let mut line = String::new();

    let x_idx = header.fields.iter().position(|f| f == "x").ok_or("Missing x field")?;
    let y_idx = header.fields.iter().position(|f| f == "y").ok_or("Missing y field")?;
    let z_idx = header.fields.iter().position(|f| f == "z").ok_or("Missing z field")?;

    let rgb_idx = header.fields.iter().position(|f| f == "rgb" || f == "rgba");
    let h_idx = header.fields.iter().position(|f| f == "h");
    let s_idx = header.fields.iter().position(|f| f == "s");
    let v_idx = header.fields.iter().position(|f| f == "v");

    for _ in 0..header.points {
        line.clear();
        let bytes_read = reader.read_line(&mut line).map_err(|e| e.to_string())?;
        if bytes_read == 0 {
            break;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let values: Vec<&str> = trimmed.split_whitespace().collect();
        if values.len() < header.fields.len() {
            continue;
        }

        let x = values[x_idx].parse::<f64>().map_err(|_| "Invalid x value")?;
        let y = values[y_idx].parse::<f64>().map_err(|_| "Invalid y value")?;
        let z = values[z_idx].parse::<f64>().map_err(|_| "Invalid z value")?;

        let has_color = !matches!(header.field_type, FieldType::XYZ);
        let color = match header.field_type {
            FieldType::XYZRGB => {
                if let Some(idx) = rgb_idx {
                    let rgb_val = values[idx].parse::<u32>().unwrap_or(0xFFFFFFFF);
                    0xFF000000 | rgb_val
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZHSV => {
                if let (Some(h_i), Some(s_i), Some(v_i)) = (h_idx, s_idx, v_idx) {
                    let h = values[h_i].parse::<f64>().unwrap_or(0.0);
                    let s = values[s_i].parse::<f64>().unwrap_or(0.0);
                    let v = values[v_i].parse::<f64>().unwrap_or(0.0);
                    hsv_to_rgb(h, s, v)
                } else {
                    0xFFFFFFFF
                }
            }
            FieldType::XYZ => 0xFFFFFFFF,
        };

        points.push(Point3D { x, y, z, color, has_color });
    }

    Ok(points)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    fn create_test_pcd_file(content: &str) -> NamedTempFile {
        let mut file = NamedTempFile::new().unwrap();
        file.write_all(content.as_bytes()).unwrap();
        file.flush().unwrap();
        file
    }

    #[test]
    fn test_parse_ascii_xyz() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 3
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 3
DATA ascii
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 3);

        assert_eq!(points[0].x, 0.0);
        assert_eq!(points[0].y, 0.0);
        assert_eq!(points[0].z, 0.0);
        assert_eq!(points[0].color, 0xFFFFFFFF);

        assert_eq!(points[1].x, 1.0);
        assert_eq!(points[2].y, 1.0);
    }

    #[test]
    fn test_parse_ascii_xyzrgb() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z rgb
SIZE 4 4 4 4
TYPE F F F U
COUNT 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
0.0 0.0 0.0 16711680
1.0 1.0 1.0 65280
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        assert_eq!(points[0].color, 0xFFFF0000);
        assert_eq!(points[1].color, 0xFF00FF00);
    }

    #[test]
    fn test_parse_ascii_xyzhsv() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z h s v
SIZE 4 4 4 4 4 4
TYPE F F F F F F
COUNT 1 1 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
0.0 0.0 0.0 0.0 1.0 1.0
1.0 1.0 1.0 120.0 1.0 1.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        assert_eq!(points[0].color & 0x00FFFFFF, 0x00FF0000);
        assert_eq!(points[1].color & 0x00FFFFFF, 0x0000FF00);
    }

    #[test]
    fn test_hsv_to_rgb_conversion() {
        let rgb = hsv_to_rgb(0.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFFFF0000);

        let rgb = hsv_to_rgb(120.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFF00FF00);

        let rgb = hsv_to_rgb(240.0, 1.0, 1.0);
        assert_eq!(rgb, 0xFF0000FF);

        let rgb = hsv_to_rgb(0.0, 0.0, 1.0);
        assert_eq!(rgb, 0xFFFFFFFF);

        let rgb = hsv_to_rgb(0.0, 0.0, 0.0);
        assert_eq!(rgb, 0xFF000000);
    }

    #[test]
    fn test_parse_ascii_xyz_marks_points_without_color_flag() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 1
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 1
DATA ascii
0.0 0.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 1);
        assert!(!points[0].has_color);
    }

    #[test]
    fn test_parse_ascii_xyzrgb_marks_points_with_color_flag() {
        let content = r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z rgb
SIZE 4 4 4 4
TYPE F F F U
COUNT 1 1 1 1
WIDTH 1
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 1
DATA ascii
0.0 0.0 0.0 16777215
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());

        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 1);
        assert!(points[0].has_color);
        assert_eq!(points[0].color, 0xFFFFFFFF);
    }

    #[test]
    fn test_parse_binary_xyz() {
        let content = String::from(r#"# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z
SIZE 4 4 4
TYPE F F F
COUNT 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA binary
"#);

        let mut file = NamedTempFile::new().unwrap();
        file.write_all(content.as_bytes()).unwrap();

        let point1: [f32; 3] = [1.0, 2.0, 3.0];
        let point2: [f32; 3] = [4.0, 5.0, 6.0];

        for &val in &point1 {
            file.write_all(&val.to_le_bytes()).unwrap();
        }
        for &val in &point2 {
            file.write_all(&val.to_le_bytes()).unwrap();
        }
        file.flush().unwrap();

        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());
        assert!(result.is_ok());
        let points = result.unwrap();
        assert_eq!(points.len(), 2);

        assert_eq!(points[0].x, 1.0);
        assert_eq!(points[0].y, 2.0);
        assert_eq!(points[0].z, 3.0);

        assert_eq!(points[1].x, 4.0);
        assert_eq!(points[1].y, 5.0);
        assert_eq!(points[1].z, 6.0);
    }

    #[test]
    fn test_invalid_file() {
        let result = parse_pcd_file("/nonexistent/file.pcd".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_header() {
        let content = "This is not a valid PCD file";
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_missing_required_fields() {
        let content = r#"VERSION 0.7
FIELDS x y z
DATA ascii
0.0 0.0 0.0
"#;
        let file = create_test_pcd_file(content);
        let result = parse_pcd_file(file.path().to_str().unwrap().to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_decimal_to_argb() {
        let rgb_decimal = 16711680.0;
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFFFF0000);

        let rgb_decimal = 65280.0;
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFF00FF00);

        let rgb_decimal = 255.0;
        let color = decimal_to_argb(rgb_decimal);
        assert_eq!(color, 0xFF0000FF);
    }
}
