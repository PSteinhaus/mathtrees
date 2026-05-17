use godot::classes::MultiMesh;
use godot::prelude::*;
use crate::ghost_node::GhostNode;

pub struct GhostTree {
    pub nodes: Vec<GhostNode>,
    pub children: Vec<usize>,
    pub growing_nodes: Vec<usize>,
}

impl GhostTree {
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            children: Vec::new(),
            growing_nodes: Vec::new(),
        }
    }

    pub fn reset(&mut self) {
        self.nodes.clear();
        self.children.clear();
        self.growing_nodes.clear();
    }

    /// creates root node
    pub fn create_root(&mut self) -> usize {
        let idx = self.nodes.len();

        self.nodes.push(GhostNode::default());

        idx
    }

    pub fn add_child(
        &mut self,
        parent: usize,
        mut node: GhostNode,
    ) -> usize {
        let idx = self.nodes.len();

        node.parent = Some(parent);

        self.nodes.push(node);

        self.children.push(idx);

        let p = &mut self.nodes[parent];

        if p.children_count == 0 {
            p.children_start = self.children.len() - 1;
        }

        p.children_count += 1;

        idx
    }
}

impl GhostNode {
    pub fn local_transform(&self) -> Transform2D {
        Transform2D::from_angle_scale_skew_origin(
            self.rotation,
            self.scale,
            0.0,
            self.position,
        )
    }
}

impl GhostTree {
    pub fn update_transforms_with_sway(
        &mut self,
        root: usize,
        time: f32,
    ) {
        self.nodes[root].global = Transform2D::IDENTITY;

        let mut stack = vec![root];

        while let Some(idx) = stack.pop() {
            let parent_global = self.nodes[idx].global;

            let start = self.nodes[idx].children_start;
            let count = self.nodes[idx].children_count;

            for i in 0..count {
                let child_idx = self.children[start + i];

                let node = &mut self.nodes[child_idx];

                // sway
                let sway =
                    (time * 0.2 + node.phase_shift).sin() * 0.18;

                node.rotation =
                    node.original_rotation + sway;

                let local = node.local_transform();

                node.global = parent_global * local;

                stack.push(child_idx);
            }
        }
    }

    pub fn write_to_multimesh(&self, multimesh: &mut Gd<MultiMesh>) {
        multimesh.set_instance_count(self.nodes.len() as i32);

        for (i, node) in self.nodes.iter().enumerate() {
            multimesh.set_instance_transform_2d(
                i as i32,
                node.global,
            );
        }
    }
}

impl GhostTree {
    pub fn is_leaf(&self, idx: usize) -> bool {
        self.nodes[idx].children_count == 0
    }
}

impl GhostTree {
    pub fn update_growth(
        &mut self,
        delta: f32,
    ) -> bool {
        // nothing animating
        if self.growing_nodes.is_empty() {
            return false;
        }

        let mut i = 0;

        while i < self.growing_nodes.len() {
            let idx = self.growing_nodes[i];

            let node = &mut self.nodes[idx];

            node.growth +=
                delta * node.growth_speed;

            if node.growth >= 1.0 {
                node.growth = 1.0;

                node.scale =
                    node.target_scale;

                // remove from active list
                self.growing_nodes
                    .swap_remove(i);

                continue;
            }

            let t = ease_out_back(node.growth);

            node.scale =
                node.target_scale * t;

            i += 1;
        }

        true
    }
}

fn ease_out_back(t: f32) -> f32 {
    let c1 = 1.70158;
    let c3 = c1 + 1.0;

    1.0 + c3 * (t - 1.0).powi(3)
        + c1 * (t - 1.0).powi(2)
}