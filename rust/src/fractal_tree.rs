use godot::prelude::*;
use godot::classes::{
    IMultiMeshInstance2D,
    Mesh,
    MultiMesh,
    ArrayMesh,
    MultiMeshInstance2D,
    RandomNumberGenerator,
};

use crate::ghost_node::GhostNode;
use crate::ghost_tree::GhostTree;
use crate::frac_kernel::FracKernel;

#[derive(GodotClass)]
#[class(base=MultiMeshInstance2D)]
pub struct FractalTreeOptimized {
    base: Base<MultiMeshInstance2D>,

    #[export]
    max_nodes: i32,

    k_type: i32,
    kernel: Option<Gd<FracKernel>>,
    ghost_tree: GhostTree,
    root_node: usize,
    time: f32,
    shrink_factor: f32,
}

#[godot_api]
impl IMultiMeshInstance2D for FractalTreeOptimized {
    fn init(base: Base<MultiMeshInstance2D>) -> Self {
        let mut tree = GhostTree::new();
        let root = tree.create_root();

        Self {
            base,
            max_nodes: 15000,
            k_type: -1,
            kernel: None,
            ghost_tree: tree,
            root_node: root,
            time: 0.0,
            shrink_factor: 0.7,
        }
    }

    fn process(&mut self, delta: f64) {
        self.time += delta as f32;

        let _growth_changed =
            self.ghost_tree
                .update_growth(delta as f32);

        self.update_multimesh_transforms();
    }
}

use crate::optimized_helpers::OptimizedHelpers;
#[godot_api]
impl FractalTreeOptimized {
    fn ensure_multimesh(&mut self) -> Gd<MultiMesh> {
        if let Some(mm) = self.base().get_multimesh() {
            return mm;
        }
    
        let mut mm = MultiMesh::new_gd();
    
        mm.set_transform_format(
            godot::classes::multi_mesh::TransformFormat::TRANSFORM_2D,
        );

        mm.set_instance_count(0);
        //mm.set_use_colors(true);
    
        self.base_mut().set_multimesh(&mm);
    
        mm
    }

    #[func]
    pub fn reinit(&mut self) {
        self.ghost_tree.reset();
        self.root_node = self.ghost_tree.create_root();
        self.shrink_factor = 0.7;
    }

    #[func]
    pub fn clear_kernel(&mut self) {
        self.k_type = -1;
        self.kernel = None;
        self.update_mesh_for_kernel();
        self.reinit();
    }

    #[func]
    pub fn node_count(& self) -> u32 {
        self.ghost_tree.nodes.len() as u32
    }

    #[func]
    pub fn update_mesh_for_kernel(&mut self) {
        let Some(kernel) = &self.kernel else {
            // set the Mesh to an empty one, if there currently is one
            let mut mm = self.ensure_multimesh();
            let mesh = ArrayMesh::new_gd();
            mm.set_mesh(&mesh.upcast::<Mesh>());
            return;
        };

        let lines = kernel.bind().get_lines();

        // around each point place some points to build our final mesh from
    	// Build mesh using Rust helper (returns Option<Gd<ArrayMesh>>)
        let line_mesh = OptimizedHelpers::create_line_mesh_from_lines(
            lines,
            14.0,
            8.0,
        );

        if let Some(mesh) = line_mesh {
            // Get the existing MultiMesh resource
            let mut mm = self.ensure_multimesh();

            // Mutate its mesh property
            mm.set_mesh(&mesh.upcast::<Mesh>());
        }

        self.update_multimesh_transforms();
    }

    #[func]
    pub fn grow(&mut self) -> bool {
        let Some(kernel) = &self.kernel else {
            return false;
        };

        let kernel_leaves = kernel.bind().get_leaves();
        let kernel_rots = kernel.bind().get_leave_rotations();

        let make_ghost_node = |pos, rot, final_scale, slot| GhostNode {
            parent: None,
            children_start: 0,
            children_count: 0,
            position: pos,
            rotation: rot,
            scale: 0.0, // start invisible
            target_scale: final_scale,
            growth: 0.0, // 0 -> 1 over time
            original_rotation: rot,
            phase_shift: rot * 2.0,
            global: Transform2D::IDENTITY,
            kernel_slot: slot,
        };

        let node_count = self.ghost_tree.nodes.len();
        if node_count == 0 {
            let node = make_ghost_node(Vector2::ZERO, 0.0, 1.0, None);
            self.ghost_tree.create_root_with(node);
            self.ghost_tree.growing_nodes.push(0); // register it for growth animation
        }

        // collect nodes once
        let mut nodes_to_process = Vec::new();
        for i in 0..self.ghost_tree.nodes.len() {
            nodes_to_process.push(i);
        }

        // reusable mask
        let mut occupied = vec![false; kernel_leaves.len()];

        let mut did_grow = false;

        for node_idx in nodes_to_process {
            let node = &self.ghost_tree.nodes[node_idx];

            // reset mask
            for v in &mut occupied {
                *v = false;
            }

            // mark existing kernel slots
            for i in 0..node.children_count {
                let child_idx =
                    self.ghost_tree.children[node.children_start + i as usize];

                if let Some(slot) =
                    self.ghost_tree.nodes[child_idx].kernel_slot
                {
                    let slot = usize::from(slot);
                    if slot < occupied.len() {
                        occupied[slot] = true;
                    }
                }
            }

            // spawn missing kernel branches
            for i in 0..kernel_leaves.len() {
                if occupied[i] {
                    continue;
                }

                if self.ghost_tree.nodes.len() >= self.max_nodes as usize {
                    break;
                }

                let pos = kernel_leaves.get(i).unwrap();
                let rot = kernel_rots.get(i).unwrap();
                let final_scale = self.shrink_factor;

                let new_node = make_ghost_node(pos, rot, final_scale, Some(i as u16));

                let new_idx =   // add_child appends at the end of the children vec, meaning we need to rebuild the children index
                    self.ghost_tree.add_child(node_idx, new_node);

                // register for animation
                self.ghost_tree.growing_nodes.push(new_idx);

                did_grow = true;
            }
        }

        self.ghost_tree.rebuild_children_index();
        self.update_multimesh_transforms();

        did_grow
    }

    #[func]
    pub fn update_multimesh_transforms(
        &mut self,
    ) {
        self.ghost_tree
            .update_transforms_with_sway(
                self.root_node,
                self.time,
            );

        let mut mm = self.ensure_multimesh();

        self.ghost_tree.write_to_multimesh(&mut mm);
    }

    #[func]
    pub fn generate_kernel(&mut self) {
        self.reinit();

        let mut rng = RandomNumberGenerator::new_gd();
        rng.randomize();

        self.k_type = rng.randi_range(0, 12);

        let mut kernel = FracKernel::new_gd();
        let mut k = kernel.bind_mut();

        match self.k_type {
            0 => {
                // two double segment arms: arching sideways
                k.add_point(Vector2::new(-20.0, -50.0));
                k.add_point(Vector2::new(-70.0, -110.0));

                let mut branch0 =
                    k.start_child_arm_from(0, Vector2::new(20.0, -50.0));

                branch0
                    .bind_mut()
                    .add_point(Vector2::new(80.0, -120.0));
            }

            1 => {
                // two double segment arms: crossing
                k.add_point(Vector2::new(0.0, -50.0));
                k.add_point(Vector2::new(-50.0, -100.0));
                k.add_point(Vector2::new(5.0, -160.0));

                let mut branch0 =
                    k.start_child_arm_from(1, Vector2::new(50.0, -50.0));

                branch0
                    .bind_mut()
                    .add_point(Vector2::new(-5.0, -100.0));
            }

            2 => {
                // one double, one single segment arm: arching up
                k.add_point(Vector2::new(-10.0, -110.0));
                k.add_point(Vector2::new(-30.0, -130.0));
                k.add_point(Vector2::new(-40.0, -190.0));

                let _branch0 =
                    k.start_child_arm_from(1, Vector2::new(30.0, -50.0));
            }

            3 => {
                // three single segment arms: arching up (middle straight)
                k.add_point(Vector2::new(0.0, -60.0));

                let _branch2 =
                    k.start_child_arm_from(1, Vector2::new(-20.0, -60.0));

                let _branch0 =
                    k.start_child_arm_from(1, Vector2::new(0.0, -190.0));

                let _branch1 =
                    k.start_child_arm_from(1, Vector2::new(20.0, -60.0));
            }

            4 => {
                // one double (straight up, then side), one single segment arm
                k.add_point(Vector2::new(-75.0, -95.0));

                let mut branch0 =
                    k.start_child_arm_from(0, Vector2::new(0.0, -130.0));

                branch0
                    .bind_mut()
                    .add_point(Vector2::new(30.0, -140.0));
            }

            5 => {
                // start straight, then double single segment arm
                k.add_point(Vector2::new(0.0, -85.0));
                k.add_point(Vector2::new(-40.0, -135.0));

                let _branch0 =
                    k.start_child_arm_from(1, Vector2::new(40.0, -50.0));
            }

            6 => {
                // three single segment arms with extended middle
                k.add_point(Vector2::new(0.0, -50.0));

                let _branch2 =
                    k.start_child_arm_from(1, Vector2::new(-40.0, -60.0));

                let mut branch0 =
                    k.start_child_arm_from(1, Vector2::new(0.0, -60.0));

                {
                    let mut b0 = branch0.bind_mut();

                    b0.add_point_rel(Vector2::new(0.0, -100.0));

                    b0.start_child_arm_from(1, Vector2::new(30.0, -40.0));
                }
            }

            7 => {
                // outward then inward
                k.add_point(Vector2::new(-120.0, -90.0));
                k.add_point(Vector2::new(-30.0, -195.0));
            
                let mut branch0 =
                    k.start_child_arm_from(0, Vector2::new(120.0, -90.0));
            
                branch0
                    .bind_mut()
                    .add_point(Vector2::new(30.0, -195.0));
            }

            8 => {
                k.add_point(Vector2::new(-150.0, -60.0));
                k.add_point(Vector2::new(0.0, -210.0));
            
                let mut branch0 =
                    k.start_child_arm_from(0, Vector2::new(150.0, -60.0));
            
                branch0
                    .bind_mut()
                    .add_point(Vector2::new(0.0, -210.0));
            }

            9 => {
                let r = 10.0;
                // this structure needs the scale to get smaller faster, so adapt it
                self.shrink_factor = 0.5;

                k.add_point(Vector2::new(0.0, -320.0));
            
                for i in 0..5 {
                    let angle =
                        -std::f32::consts::FRAC_PI_2 +
                        i as f32 * std::f32::consts::TAU / 5.0;
            
                    let p = Vector2::new(
                        angle.cos() * r,
                        angle.sin() * r,
                    );
            
                    k.start_child_arm_from(1, p);
                }
            }

            10 => {
                // extend horizontally first, then curl upward
            
                k.add_point(Vector2::new(50.0, -20.0));
                k.add_point(Vector2::new(90.0, -60.0));
                k.add_point(Vector2::new(110.0, -130.0));
                k.add_point(Vector2::new(90.0, -160.0));
                k.add_point(Vector2::new(70.0, -190.0));
            
                let mut branch0 =
                    k.start_child_arm_from(
                        2,
                        Vector2::new(20.0, -30.0),
                    );
            
                {
                    let mut b = branch0.bind_mut();
            
                    b.add_point_rel(Vector2::new(
                        10.0,
                        -30.0,
                    ));
                }
            }

            11 => {
                k.add_point(Vector2::new(120.0, -120.0));
            
                let _branch =
                    k.start_child_arm_from(
                        1,
                        Vector2::new(-20.0, -35.0),
                    );
            }

            _ => {
                // two double segment arms: arching up
                k.add_point(Vector2::new(-40.0, -50.0));
                k.add_point(Vector2::new(-70.0, -110.0));

                let mut branch0 =
                    k.start_child_arm_from(0, Vector2::new(50.0, -50.0));

                branch0
                    .bind_mut()
                    .add_point(Vector2::new(80.0, -120.0));
            }
        }
        drop(k);

        self.kernel = Some(kernel);
        self.update_mesh_for_kernel();
    }

    /// returns the detached subtree
    #[func]
    pub fn detach_closest_subtree_at(&mut self, local_pos: Vector2) -> Option<Gd<FractalTreeOptimized>> {
        if let Some(idx) = self.ghost_tree.find_closest_node(local_pos)
        {
            const DIST_THRESHOLD: f32 = 25.0;
            let n: &GhostNode = self.ghost_tree.get_node(idx);
            if local_pos.distance_to(n.global_pos()) <= DIST_THRESHOLD {
                let detached: GhostTree = self.ghost_tree.extract_subtree(idx);
                let mut detached_fractal_tree = FractalTreeOptimized::new_alloc();
                let cloned_mm = self.create_multimesh_with_shared_mesh();
                detached_fractal_tree.bind_mut().ghost_tree = detached;
                detached_fractal_tree.bind_mut().base_mut().set_multimesh(&cloned_mm?);
                detached_fractal_tree.bind_mut().k_type = self.k_type;
                detached_fractal_tree.bind_mut().kernel = self.kernel.clone();
                return Some(detached_fractal_tree)
            }
        }
        None
    }

    #[func]
    pub fn add_branch_at_closest_joint(&mut self, local_pos: Vector2) {
        // rotate the local_pos according to the current root node rotation
        let root_rot = self.root_rot();
        let local_pos = local_pos.rotated(-root_rot);

        let kernel = self.kernel.get_or_insert_with(|| {
            self.k_type = -2;
            FracKernel::new_gd()
        });

        // find the closest kernel and arm index relative to the given position
        let Some((mut k, i)) = kernel.bind().find_closest_point_owner(local_pos) else {
            return;
        };

        // compute relative position BEFORE mutable bind
        let k_pos_rel = kernel
            .bind()
            .get_descendant_position(&k)
            .unwrap();
        let k_pos_rel = k_pos_rel + k.bind().get_arm_pos(i).unwrap();

        {
            let mut k_bind = k.bind_mut();

            if i == k_bind.arm_len() {
                k_bind.add_point(local_pos);
            } else {
                k_bind.start_child_arm_from(
                    i as i32,
                    local_pos - k_pos_rel,
                );
            }
        }

        self.update_mesh_for_kernel();
    }

    fn create_multimesh_with_shared_mesh(&mut self) -> Option<Gd<MultiMesh>> {
        let src_mm = self.ensure_multimesh();
        
        let mesh = src_mm.get_mesh();
        
        let mut new_mm = MultiMesh::new_gd();
        
        new_mm.set_transform_format(
            godot::classes::multi_mesh::TransformFormat::TRANSFORM_2D,
        );

        new_mm.set_instance_count(0);
        //new_mm.set_use_colors(true);
        
        if let Some(mesh) = mesh {
            new_mm.set_mesh(&mesh);
        }

        Some(new_mm)
    }

    #[func]
    pub fn root_scale(&self) -> Vector2 { 
        if let Some(r) = self.ghost_tree.get_root() {
            return  Vector2{x: r.scale, y: r.scale};
        } else {
            Vector2::INF    // return INF as an easily debugable crap value
        }
    }

    #[func]
    pub fn root_rot(&self) -> f32 { 
        if let Some(r) = self.ghost_tree.get_root() {
            return  r.rotation;
        } else {
            0.
        }
    }
}