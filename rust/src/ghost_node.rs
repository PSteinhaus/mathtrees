use godot::prelude::*;

#[derive(Clone, Copy, Debug)]
pub struct GhostNode {
    pub parent: Option<usize>,

    pub children_start: usize,
    pub children_count: usize,

    // local transform
    pub position: Vector2,
    pub rotation: f32,
    pub scale: Vector2,

    // sway
    pub original_rotation: f32,
    pub phase_shift: f32,

    // cached global transform
    pub global: Transform2D,

    // growth animation
    pub target_scale: Vector2,
    pub growth: f32,
    pub growth_speed: f32,
}

impl Default for GhostNode {
    fn default() -> Self {
        Self {
            parent: None,

            children_start: 0,
            children_count: 0,

            position: Vector2::ZERO,
            rotation: 0.0,
            scale: Vector2::ONE,

            original_rotation: 0.0,
            phase_shift: 0.0,

            global: Transform2D::IDENTITY,

            target_scale: Vector2::ONE,
            growth: 1.0,
            growth_speed: 1.0,
        }
    }
}