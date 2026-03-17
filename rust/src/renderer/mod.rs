use std::collections::HashMap;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Mutex, OnceLock};

#[derive(Default, Clone)]
pub struct RendererScene {
    pub point_count: usize,
    pub line_vertex_count: usize,
    pub rotation_x: f32,
    pub rotation_y: f32,
    pub zoom: f32,
    pub point_size: f32,
    pub background_argb: u32,
}

static RENDERER_ID: AtomicI64 = AtomicI64::new(1);
static RENDERERS: OnceLock<Mutex<HashMap<i64, RendererScene>>> = OnceLock::new();

fn renderers() -> &'static Mutex<HashMap<i64, RendererScene>> {
    RENDERERS.get_or_init(|| Mutex::new(HashMap::new()))
}

#[no_mangle]
pub extern "C" fn fpv_renderer_create() -> i64 {
    let id = RENDERER_ID.fetch_add(1, Ordering::Relaxed);
    let mut store = renderers().lock().expect("renderer store poisoned");
    store.insert(id, RendererScene::default());
    id
}

#[no_mangle]
pub extern "C" fn fpv_renderer_dispose(renderer_id: i64) {
    let mut store = renderers().lock().expect("renderer store poisoned");
    store.remove(&renderer_id);
}

#[no_mangle]
pub extern "C" fn fpv_renderer_update_camera(
    renderer_id: i64,
    rotation_x: f32,
    rotation_y: f32,
    zoom: f32,
) -> bool {
    let mut store = renderers().lock().expect("renderer store poisoned");
    if let Some(scene) = store.get_mut(&renderer_id) {
        scene.rotation_x = rotation_x;
        scene.rotation_y = rotation_y;
        scene.zoom = zoom;
        true
    } else {
        false
    }
}

#[no_mangle]
pub extern "C" fn fpv_renderer_update_config(
    renderer_id: i64,
    point_size: f32,
    background_argb: u32,
) -> bool {
    let mut store = renderers().lock().expect("renderer store poisoned");
    if let Some(scene) = store.get_mut(&renderer_id) {
        scene.point_size = point_size;
        scene.background_argb = background_argb;
        true
    } else {
        false
    }
}

#[no_mangle]
pub extern "C" fn fpv_renderer_load_scene(
    renderer_id: i64,
    point_count: usize,
    line_vertex_count: usize,
) -> bool {
    let mut store = renderers().lock().expect("renderer store poisoned");
    if let Some(scene) = store.get_mut(&renderer_id) {
        scene.point_count = point_count;
        scene.line_vertex_count = line_vertex_count;
        true
    } else {
        false
    }
}
