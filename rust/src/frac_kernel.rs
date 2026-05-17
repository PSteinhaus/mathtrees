use godot::prelude::*;
use godot::classes::RefCounted;

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FracKernel {
    base: Base<RefCounted>,

    /// first point is always (0,0)
    core_arm: Vec<Vector2>,

    /// (child kernel, attach index)
    child_arms: Vec<(Gd<FracKernel>, i32)>,
}

#[godot_api]
impl IRefCounted for FracKernel {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            core_arm: vec![Vector2::ZERO],
            child_arms: vec![],
        }
    }
}

#[godot_api]
impl FracKernel {
    #[func]
    pub fn add_point(&mut self, pos: Vector2) {
        self.core_arm.push(pos);
    }

    #[func]
    pub fn add_point_rel(&mut self, pos: Vector2) {
        let last = *self.core_arm.last().unwrap();
        self.core_arm.push(last + pos);
    }

    #[func]
    pub fn add_child(&mut self, child: Gd<FracKernel>, index: i32) {
        self.child_arms.push((child, index));
    }

    #[func]
    pub fn start_child_arm_from(
        &mut self,
        start_index: i32,
        relative_pos: Vector2,
    ) -> Gd<FracKernel> {
        let mut child = FracKernel::new_gd();

        child.bind_mut().add_point(relative_pos);
        self.child_arms.push((child.clone(), start_index));

        child
    }

    #[func]
    pub fn get_lines(&self) -> PackedVector2Array {
        let mut lines = PackedVector2Array::new();

        for i in 0..self.core_arm.len().saturating_sub(1) {
            lines.push(self.core_arm[i]);
            lines.push(self.core_arm[i + 1]);
        }

        for (child, idx) in &self.child_arms {
            let start = self.core_arm[*idx as usize];
            let child_lines = child.bind().get_lines();

            for i in 0..child_lines.len() {
                let p = child_lines.get(i).expect("faulty line!");
                lines.push(start + p);
            }
        }

        lines
    }

    #[func]
    pub fn get_leaves(&self) -> Array<Vector2> {
        let mut leaves = Array::new();

        let end_index = self.core_arm.len() - 1;

        let has_child_at_tip = self
            .child_arms
            .iter()
            .any(|(_, i)| *i as usize == end_index);

        if !has_child_at_tip {
            leaves.push(self.core_arm[end_index]);
        }

        for (child, idx) in &self.child_arms {
            let start = self.core_arm[*idx as usize];

            for leaf in child.bind().get_leaves().iter_shared() {
                leaves.push(start + leaf);
            }
        }

        leaves
    }

    #[func]
    pub fn get_leave_rotations(&self) -> Array<f32> {
        let mut rots = Array::new();

        let end_index = self.core_arm.len() - 1;

        let has_child_at_tip = self
            .child_arms
            .iter()
            .any(|(_, i)| *i as usize == end_index);

        if !has_child_at_tip {
            if end_index > 0 {
                let angle = self.core_arm[end_index - 1]
                    .angle_to_point(self.core_arm[end_index]);

                rots.push(angle + std::f32::consts::PI * 0.5);
            } else {
                rots.push(0.0);
            }
        }

        for (child, _) in &self.child_arms {
            let child_rots = child.bind().get_leave_rotations();
            for i in 0..child_rots.len() {
                rots.push(child_rots.get(i).expect("faulty other rot!"));
            }
        }

        rots
    }
}