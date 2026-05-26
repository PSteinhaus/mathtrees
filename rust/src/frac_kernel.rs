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
    pub fn get_arm_pos(&self, i: usize,) -> Option<Vector2> {
        self.core_arm.get(i).copied()
    }

    #[func]
    pub fn add_point(&mut self, pos: Vector2) {
        if Some(&pos) != self.core_arm.last() {
            self.core_arm.push(pos);
        }
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

    pub fn arm_len(&self) -> usize {
        self.core_arm.len()
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

    pub fn find_closest_point_owner(
        &self,
        target: Vector2,
    ) -> Option<(Gd<FracKernel>, usize)> {
        let mut best_dist_sq = f32::INFINITY;
        let mut best: Option<(Gd<FracKernel>, usize)> = None;
    
        self.find_closest_point_owner_recursive(
            target,
            Vector2::ZERO,
            &mut best_dist_sq,
            &mut best,
        );
    
        best
    }
    
    fn find_closest_point_owner_recursive(
        &self,
        target: Vector2,
        offset: Vector2,
        best_dist_sq: &mut f32,
        best: &mut Option<(Gd<FracKernel>, usize)>,
    ) {
        // Search local points
        for (i, p) in self.core_arm.iter().enumerate() {
            let world_pos = offset + *p;
            let dist_sq = world_pos.distance_squared_to(target);
    
            if dist_sq < *best_dist_sq {
                *best_dist_sq = dist_sq;
                *best = Some((self.to_gd(), i));
            }
        }
    
        // Search children
        for (child, idx) in &self.child_arms {
            let child_offset = offset + self.core_arm[*idx as usize];
    
            child.bind().find_closest_point_owner_recursive(
                target,
                child_offset,
                best_dist_sq,
                best,
            );
        }
    }

    pub fn get_descendant_position(
        &self,
        target: &Gd<FracKernel>,
    ) -> Option<Vector2> {
        // self is at (0,0) relative to itself
        self.get_descendant_position_recursive(target, Vector2::ZERO)
    }
    
    fn get_descendant_position_recursive(
        &self,
        target: &Gd<FracKernel>,
        offset: Vector2,
    ) -> Option<Vector2> {
        // Compare object identity
        if self.to_gd().instance_id() == target.instance_id() {
            return Some(offset);
        }
    
        for (child, idx) in &self.child_arms {
            let child_offset = offset + self.core_arm[*idx as usize];
    
            if let Some(pos) = child
                .bind()
                .get_descendant_position_recursive(target, child_offset)
            {
                return Some(pos);
            }
        }
    
        None
    }
}