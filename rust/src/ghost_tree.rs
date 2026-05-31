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

    pub fn create_root(&mut self) -> usize {
        self.create_root_with(GhostNode::default())
    }

    pub fn create_root_with(&mut self, node: GhostNode) -> usize {
        let idx = self.nodes.len();
        self.nodes.push(node);
        idx
    }

    pub fn get_root(&self) -> Option<&GhostNode> {
        self.nodes.get(0)
    }

    pub fn get_mut_root(&mut self) -> Option<&mut GhostNode> {
        self.nodes.get_mut(0)
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

    pub fn get_node(&self, id: usize) -> &GhostNode {
        return &self.nodes[id]
    }
}

impl GhostNode {
    pub fn local_transform(&self) -> Transform2D {
        Transform2D::from_angle_scale_skew_origin(
            self.rotation,
            Vector2{ x: self.scale, y: self.scale },
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
        if self.nodes.get(root).is_none() { return }
        let mut stack = vec![(root, Transform2D::IDENTITY)];
    
        while let Some((idx, parent_global)) = stack.pop() {
            let node = &mut self.nodes[idx];
    
            // apply sway to every node (including root)
            let sway = (time * 0.2 + node.phase_shift).sin() * 0.18;
            node.rotation = node.original_rotation + sway;
    
            // compute global transform
            let local = node.local_transform();
            node.global = parent_global * local;
    
            // push children with this node's global as their parent
            let start = node.children_start;
            let count = node.children_count;
    
            for i in 0..count {
                let child_idx = self.children[start + i as usize];
                stack.push((child_idx, node.global));
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

            // multimesh.set_instance_color(
            //     i as i32,
            //     Color::from_rgb(1.0, 0.0, 0.0), // example: red
            // );
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
                delta * crate::ghost_node::GROWTH_SPEED;

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

impl GhostTree {
    pub fn find_closest_node(
        &self,
        position: Vector2,
    ) -> Option<usize> {
        let mut best_idx = None;
        let mut best_dist = f32::MAX;

        for (i, node) in self.nodes.iter().enumerate() {
            let node_pos = node.global_pos();

            let dist = node_pos.distance_squared_to(position);

            if dist < best_dist {
                best_dist = dist;
                best_idx = Some(i);
            }
        }

        best_idx
    }

    pub fn collect_subtree(
        &self,
        root: usize,
    ) -> Vec<usize> {
        let mut result = Vec::new();
        let mut stack = vec![root];

        while let Some(idx) = stack.pop() {
            result.push(idx);

            let node = &self.nodes[idx];

            for i in 0..node.children_count {
                let child_idx =
                    self.children[node.children_start + i as usize];

                stack.push(child_idx);
            }
        }

        result
    }
}

use std::{collections::{HashMap, HashSet}, usize};

impl GhostTree {
    pub fn extract_subtree(
        &mut self,
        root_idx: usize,
    ) -> GhostTree {
        // all nodes to move
        let subtree_nodes =
            self.collect_subtree(root_idx);

        let subtree_set: HashSet<usize> =
            subtree_nodes.iter().copied().collect();

        //
        // BUILD NEW TREE
        //

        let mut new_tree = GhostTree::new();

        // old idx -> new idx
        let mut remap = HashMap::new();

        // clone nodes
        for old_idx in &subtree_nodes {
            let mut node =
                self.nodes[*old_idx].clone();

            node.parent = None;
            node.children_count = 0;
            node.children_start = 0;

            let new_idx = new_tree.nodes.len();

            new_tree.nodes.push(node);

            remap.insert(*old_idx, new_idx);
        }

        // rebuild hierarchy
        for old_idx in &subtree_nodes {
            let old_node = &self.nodes[*old_idx];

            let new_idx = remap[old_idx];

            for i in 0..old_node.children_count {
                let old_child =
                    self.children
                        [old_node.children_start + i as usize];

                if !subtree_set.contains(&old_child) {
                    continue;
                }

                let new_child =
                    remap[&old_child];

                new_tree.children.push(new_child);
                let node_id = new_tree.children.len() - 1;
                new_tree.growing_nodes.push(node_id);   // adding all nodes as growing nodes should be ok, as they get checked and thrown out immediately, if they are not growing

                let parent =
                    &mut new_tree.nodes[new_idx];

                if parent.children_count == 0 {
                    parent.children_start = node_id;
                }

                parent.children_count += 1;

                new_tree.nodes[new_child].parent =
                    Some(new_idx);
            }
        }

        //
        // REBUILD CURRENT TREE
        //

        let keep_nodes: Vec<usize> =
            (0..self.nodes.len())
                .filter(|i| !subtree_set.contains(i))
                .collect();

        let old_nodes =
            std::mem::take(&mut self.nodes);

        let old_children =
            std::mem::take(&mut self.children);
        
        let old_growing =
            std::mem::take(&mut self.growing_nodes);

        let mut remap_old = HashMap::new();

        for old_idx in &keep_nodes {
            let mut node =
                old_nodes[*old_idx].clone();

            node.parent = None;
            node.children_count = 0;
            node.children_start = 0;

            let new_idx = self.nodes.len();

            self.nodes.push(node);

            remap_old.insert(*old_idx, new_idx);
        }

        for old_idx in &keep_nodes {
            let old_node = &old_nodes[*old_idx];

            let new_idx = remap_old[old_idx];

            for i in 0..old_node.children_count {
                let old_child =
                    old_children
                        [old_node.children_start + i as usize];

                if subtree_set.contains(&old_child) {
                    continue;
                }

                let new_child =
                    remap_old[&old_child];

                self.children.push(new_child);

                let parent =
                    &mut self.nodes[new_idx];

                if parent.children_count == 0 {
                    parent.children_start =
                        self.children.len() - 1;
                }

                parent.children_count += 1;

                self.nodes[new_child].parent =
                    Some(new_idx);
            }
        }

        for old_idx in &old_growing {
            if let Some(new_id) = remap_old.get(old_idx) {
                self.growing_nodes.push(*new_id)
            }
        }

        // finally, let the new tree retain its scale, by giving its root its global scale inside the old tree:
        if let Some(new_root) = new_tree.get_mut_root() {
            let s = new_root.global.scale();
            godot_print!("global scale: {}", s);
            new_root.scale = s.x;
            new_root.target_scale = s.x;
            new_root.position = Vector2::ZERO;
        }
        new_tree
    }
}