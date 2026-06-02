use godot::prelude::*;

#[derive(Clone, Copy)]
pub struct GhostNode {
    pub kernel_slot: Option<u16>,

    pub position: Vector2,
    pub rotation: f32,
    pub scale: f32,

    pub original_rotation: f32,
    pub phase_shift: f32,

    pub target_scale: f32,
    pub growth: f32,
}

impl Default for GhostNode {
    fn default() -> Self {
        Self {
            kernel_slot: None,

            position: Vector2::ZERO,
            rotation: 0.0,
            scale: 1.0,

            original_rotation: 0.0,
            phase_shift: 0.0,

            target_scale: 1.0,
            growth: 1.0,
        }
    }
}