use godot::prelude::*;

#[derive(Clone, Copy, Debug)]
pub struct GhostNode {
    pub parent: Option<usize>,
    pub kernel_slot: Option<u16>,

    pub children_start: usize,
    pub children_count: u16,

    // local transform
    pub position: Vector2,
    pub rotation: f32,
    pub scale: f32,

    // sway
    pub original_rotation: f32,
    pub phase_shift: f32,

    // cached global transform
    pub global: Transform2D,

    // growth animation
    pub target_scale: f32,
    pub growth: f32,
}
pub(crate) const GROWTH_SPEED: f32 = 0.2;

impl Default for GhostNode {
    fn default() -> Self {
        Self {
            parent: None,
            kernel_slot: None,

            children_start: 0,
            children_count: 0,

            position: Vector2::ZERO,
            rotation: 0.0,
            scale: 1.,

            original_rotation: 0.0,
            phase_shift: 0.0,

            global: Transform2D::IDENTITY,

            target_scale: 1.0,
            growth: 1.0,
        }
    }
}

impl GhostNode {
    pub fn global_pos(&self) -> Vector2 {
        return self.global.origin
    }
}