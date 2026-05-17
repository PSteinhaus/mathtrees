use godot::prelude::*;
use godot::classes::Time;

#[derive(GodotClass)]
#[class(base = Node2D)]
pub struct SwayNode2DOptimized {
    base: Base<Node2D>,

    original_rot: f32,
    phase_shift: f32,
}

#[godot_api]
impl INode2D for SwayNode2DOptimized {
    fn init(base: Base<Node2D>) -> Self {
        Self {
            base,
            original_rot: 0.0,
            phase_shift: 0.0,
        }
    }

    fn ready(&mut self) {
        // Capture initial rotation (equivalent to GDScript implicit expectation)
        self.original_rot = self.base().get_rotation();
    }

    fn process(&mut self, _delta: f64) {
        const SWAY_AMP: f32 = 0.2;
        const SWAY_FREQ: f32 = 0.18;

        // Better: use engine time API directly
        let time_ms = Time::singleton().get_ticks_msec() as f32;

        let rot_offset =
            SWAY_AMP * (SWAY_FREQ * 0.001 * time_ms + self.phase_shift).sin();

        let rot = self.original_rot + rot_offset;

        self.base_mut().set_rotation(rot);
    }
}