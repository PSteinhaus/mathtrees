use godot::classes::MultiMesh;
use godot::prelude::*;
use crate::ghost_node::GhostNode;

pub type NodeId = usize;

pub struct GhostTree {
    // hierarchy
    pub parent: Vec<Option<usize>>,
    pub kernel_slot: Vec<Option<u16>>,
    // adjacency
    pub children: Vec<usize>,
    pub children_start: Vec<usize>,
    pub children_count: Vec<u16>,

    // local transform
    pub position: Vec<Vector2>,
    pub rotation: Vec<f32>,
    pub scale: Vec<f32>,

    // sway
    pub original_rotation: Vec<f32>,
    pub phase_shift: Vec<f32>,

    // cached global transform
    pub global: Vec<Transform2D>,

    // growth animation
    pub target_scale: Vec<f32>,
    pub growth: Vec<f32>,

    // active growth list
    pub growing_nodes: Vec<usize>,

    multimesh_buffer: Vec<f32>,
}

impl GhostTree {
    pub fn new() -> Self {
        Self {
            parent: Vec::new(),
            kernel_slot: Vec::new(),
            children: Vec::new(),
            children_start: Vec::new(),
            children_count: Vec::new(),

            position: Vec::new(),
            rotation: Vec::new(),
            scale: Vec::new(),

            original_rotation: Vec::new(),
            phase_shift: Vec::new(),

            global: Vec::new(),

            target_scale: Vec::new(),
            growth: Vec::new(),

            growing_nodes: Vec::new(),

            multimesh_buffer: Vec::new(),
        }
    }

    pub fn len(&self) -> usize {
        self.parent.len()
    }

    pub fn reset(&mut self) {
        self.parent.clear();
        self.kernel_slot.clear();
        self.children.clear();
        self.children_start.clear();
        self.children_count.clear();

        self.position.clear();
        self.rotation.clear();
        self.scale.clear();

        self.original_rotation.clear();
        self.phase_shift.clear();

        self.global.clear();

        self.target_scale.clear();
        self.growth.clear();

        self.growing_nodes.clear();

        self.multimesh_buffer.clear();
    }

    fn push_node(
        &mut self,
        parent: Option<usize>,
        node: GhostNode,
    ) -> usize {
        let idx = self.len();

        self.parent.push(parent);
        self.kernel_slot.push(node.kernel_slot);

        self.children_start.push(0);
        self.children_count.push(0);

        self.position.push(node.position);
        self.rotation.push(node.rotation);
        self.scale.push(node.scale);

        self.original_rotation.push(node.original_rotation);
        self.phase_shift.push(node.phase_shift);

        self.global.push(Transform2D::IDENTITY);

        self.target_scale.push(node.target_scale);
        self.growth.push(node.growth);

        idx
    }

    pub fn create_root(&mut self) -> usize {
        self.push_node(None, GhostNode::default())
    }

    pub fn create_root_with(
        &mut self,
        node: GhostNode,
    ) -> usize {
        self.push_node(None, node)
    }

    pub fn get_root(&self) -> Option<GhostNode> {
        if self.len() >= 1 {
            Some(self.get_node(0))
        } else {
            None
        }
    }

    pub fn global_pos(&self, node_id: NodeId) -> Vector2 {
        return self.global[node_id].origin
    }

    /// Assumes to be called repeatedly until ALL children of a node are defined.
    /// If that is not the case (so if it is called out of sequence) then you need to use rebuild_children_index
    pub fn add_child(
        &mut self,
        parent: usize,
        node: GhostNode,
    ) -> usize {
        let idx = self.push_node(Some(parent), node);
    
        self.children.push(idx);
    
        if self.children_count[parent] == 0 {
            self.children_start[parent] =
                self.children.len() - 1;
        }
    
        self.children_count[parent] += 1;
    
        idx
    }

    pub fn get_node(&self, id: usize) -> GhostNode {
        GhostNode {
            kernel_slot: self.kernel_slot[id],
            position: self.position[id],
            rotation: self.rotation[id],
            scale: self.scale[id],
            original_rotation: self.original_rotation[id],
            phase_shift: self.phase_shift[id],
            target_scale: self.target_scale[id],
            growth: self.growth[id],
        }
    }
}

// impl GhostNode {
//     pub fn local_transform(&self) -> Transform2D {
//         Transform2D::from_angle_scale_skew_origin(
//             self.rotation,
//             Vector2{ x: self.scale, y: self.scale },
//             0.0,
//             self.position,
//         )
//     }
// }

impl GhostTree {
    pub fn update_transforms_with_sway(
        &mut self,
        root: usize,
        time: f32,
    ) {
        if root >= self.len() {
            return;
        }

        let mut stack =
            vec![(root, Transform2D::IDENTITY)];

        while let Some((idx, parent_global)) =
            stack.pop()
        {
            // apply sway to every node (including root)
            let sway = (time * 0.2 + self.phase_shift[idx]).sin() * 0.18;
            self.rotation[idx] = self.original_rotation[idx] + sway;

             // compute global transform
            let local =
                Transform2D::from_angle_scale_skew_origin(
                    self.rotation[idx],
                    Vector2::ONE * self.scale[idx],
                    0.0,
                    self.position[idx],
                );

            let global = parent_global * local;
            self.global[idx] = global;

            // push children with this node's global as their parent
            let start = self.children_start[idx];
            let count = self.children_count[idx];

            for i in 0..count {
                let child = self.children[start + i as usize];
                stack.push((child, global));
            }
        }
    }

    pub fn write_to_multimesh(
        &mut self,
        multimesh: &mut Gd<MultiMesh>,
    ) {
        let count = self.global.len();
    
        multimesh.set_instance_count(count as i32);
    
        self.multimesh_buffer.clear();
        self.multimesh_buffer.reserve(count * 8);
    
        for t in &self.global {
            self.multimesh_buffer.extend_from_slice(&[
                t.a.x,
                t.b.x,
                0.0,
                t.origin.x,
    
                t.a.y,
                t.b.y,
                0.0,
                t.origin.y,
            ]);
        }
    
        let packed =
            PackedFloat32Array::from(self.multimesh_buffer.as_slice());
    
        multimesh.set_buffer(&packed);
    }
}

// impl GhostTree {
//     pub fn is_leaf(&self, idx: usize) -> bool {
//         self.nodes[idx].children_count == 0
//     }
// }

const GROWTH_SPEED: f32 = 0.2;

impl GhostTree {
    pub fn update_growth(
        &mut self,
        delta: f32,
    ) -> bool {
        if self.growing_nodes.is_empty() {
            return false;
        }
    
        let mut i = 0;
    
        while i < self.growing_nodes.len() {
            let idx = self.growing_nodes[i];
    
            self.growth[idx] += delta * GROWTH_SPEED;
    
            if self.growth[idx] >= 1.0 {
                self.growth[idx] = 1.0;
                self.scale[idx] = self.target_scale[idx];
                // remove from active list
                self.growing_nodes.swap_remove(i);
                continue;
            }
    
            let t = ease_out_back(self.growth[idx]);
    
            self.scale[idx] =
                self.target_scale[idx] * t;
    
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

impl GhostTree {
    pub fn find_closest_node(
        &self,
        position: Vector2,
    ) -> Option<usize> {
        let mut best = None;
        let mut best_dist = f32::MAX;
    
        for (i, global) in self.global.iter().enumerate() {
            let dist = global.origin.distance_squared_to(position);
    
            if dist < best_dist {
                best_dist = dist;
                best = Some(i);
            }
        }
    
        best
    }

    pub fn collect_subtree(
        &self,
        root: usize,
    ) -> Vec<usize> {
        let mut result = Vec::new();
        let mut stack = vec![root];
    
        while let Some(idx) = stack.pop() {
            result.push(idx);
    
            let start = self.children_start[idx];
            let count = self.children_count[idx];
    
            for i in 0..count {
                let child = self.children[start + i as usize];
                stack.push(child);
            }
        }
    
        result
    }
}

use std::{collections::{HashMap, HashSet}, usize};

impl GhostTree {
    fn copy_node_from(
        &mut self,
        src: &GhostTree,
        old_idx: usize,
    ) -> usize {
        let new_idx = self.parent.len();

        self.parent.push(None);
        self.kernel_slot.push(src.kernel_slot[old_idx]);

        self.children_start.push(0);
        self.children_count.push(0);

        self.position.push(src.position[old_idx]);
        self.rotation.push(src.rotation[old_idx]);
        self.scale.push(src.scale[old_idx]);

        self.original_rotation
            .push(src.original_rotation[old_idx]);

        self.phase_shift
            .push(src.phase_shift[old_idx]);

        self.global.push(src.global[old_idx]);

        self.target_scale
            .push(src.target_scale[old_idx]);

        self.growth.push(src.growth[old_idx]);

        new_idx
    }

    pub fn extract_subtree(
        &mut self,
        root_idx: usize,
    ) -> GhostTree {
        let subtree_nodes =
            self.collect_subtree(root_idx);

        let subtree_set: HashSet<usize> =
            subtree_nodes.iter().copied().collect();

        //
        // BUILD NEW TREE
        //

        let mut new_tree = GhostTree::new();

        let mut remap = HashMap::new();

        for &old_idx in &subtree_nodes {
            let new_idx = new_tree.copy_node_from(self, old_idx);

            remap.insert(old_idx, new_idx);
        }

        for &old_idx in &subtree_nodes {
            let new_parent = remap[&old_idx];

            let start = self.children_start[old_idx];
            let count = self.children_count[old_idx];

            for i in 0..count {
                let old_child = self.children[start + i as usize];

                if !subtree_set.contains(&old_child) {
                    continue;
                }

                let new_child = remap[&old_child];

                let edge_idx = new_tree.children.len();

                new_tree.children.push(new_child);

                if new_tree.children_count[new_parent] == 0
                {
                    new_tree.children_start[new_parent] = edge_idx;
                }

                new_tree.children_count[new_parent] += 1;

                new_tree.parent[new_child] = Some(new_parent);
            }
        }

        //
        // REBUILD ORIGINAL TREE
        //

        let keep_nodes: Vec<usize> =
            (0..self.parent.len())
                .filter(|i| !subtree_set.contains(i))
                .collect();

        let old_tree = std::mem::replace(self, GhostTree::new());

        let mut remap_old = HashMap::new();

        for &old_idx in &keep_nodes {
            let new_idx = self.copy_node_from(&old_tree, old_idx);

            remap_old.insert(old_idx, new_idx);
        }

        for &old_idx in &keep_nodes {
            let new_parent = remap_old[&old_idx];

            let start = old_tree.children_start[old_idx];

            let count = old_tree.children_count[old_idx];

            for i in 0..count {
                let old_child = old_tree.children[start + i as usize];

                if subtree_set.contains(&old_child) {
                    continue;
                }

                let new_child = remap_old[&old_child];

                let edge_idx = self.children.len();

                self.children.push(new_child);

                if self.children_count[new_parent] == 0
                {
                    self.children_start[new_parent] = edge_idx;
                }

                self.children_count[new_parent] += 1;

                self.parent[new_child] = Some(new_parent);
            }
        }

        for &old_idx in &old_tree.growing_nodes {
            if let Some(&new_idx) = remap_old.get(&old_idx)
            {
                self.growing_nodes.push(new_idx);
            }
        }

        //
        // PRESERVE ROOT SCALE
        //

        if !new_tree.parent.is_empty() {
            let root = 0;

            let s = new_tree.global[root].scale();

            new_tree.scale[root] = s.x;
            new_tree.target_scale[root] = s.x;
            new_tree.position[root] = Vector2::ZERO;
        }

        new_tree
    }

    pub fn rebuild_children_index(
        &mut self,
    ) {
        let node_count = self.parent.len();

        //
        // COUNT CHILDREN
        //

        self.children_count.fill(0);

        for child_idx in 0..node_count {
            if let Some(parent) = self.parent[child_idx]
            {
                self.children_count[parent] += 1;
            }
        }

        //
        // PREFIX SUM
        //

        let mut offset = 0usize;

        for i in 0..node_count {
            self.children_start[i] = offset;

            offset += self.children_count[i] as usize;
        }

        //
        // BUILD CHILD ARRAY
        //

        self.children.clear();
        self.children.resize(offset, 0);

        let mut cursor = self.children_start.clone();

        for child_idx in 0..node_count {
            if let Some(parent) = self.parent[child_idx]
            {
                let pos = cursor[parent];
                self.children[pos] = child_idx;
                cursor[parent] += 1;
            }
        }
    }
}
