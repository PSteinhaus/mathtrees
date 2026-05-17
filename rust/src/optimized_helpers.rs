use godot::prelude::*;
use godot::classes::MultiMesh;
use godot::builtin::Transform2D;
use godot::classes::{ArrayMesh};
use godot::builtin::{PackedVector2Array, PackedColorArray, Color, Vector2};
use godot::classes::mesh::PrimitiveType;
use godot::classes::mesh::ArrayType;

#[derive(GodotClass)]
#[class(base=Object)]
pub struct OptimizedHelpers;

#[godot_api]
impl IObject for OptimizedHelpers {
    fn init(_base: Base<Object>) -> Self {
        Self
    }
}

#[godot_api]
impl OptimizedHelpers {
    /// Distance from point p1 to infinite line p0->p2 (squared)
    pub fn dist_to_line_squared(p0: Vector2, p1: Vector2, p2: Vector2) -> f32 {
        let dx = p2.x - p0.x;
        let dy = p2.y - p0.y;

        let denom = dx * dx + dy * dy;
        if denom == 0.0 {
            return 0.0;
        }

        let numerator = (dy * p1.x - dx * p1.y + p2.x * p0.y - p2.y * p0.x).abs();

        (numerator * numerator) / denom
    }

/// Push a new instance into a MultiMesh while preserving existing transforms.
    pub fn push_back_instance_in_multimesh(
        mut mm: Gd<MultiMesh>,
        transform: Transform2D,
    ) {
        let old_count = mm.get_instance_count();
        let new_count = old_count + 1;

        // Backup existing transforms
        let mut transforms: Vec<Transform2D> = Vec::with_capacity(old_count as usize);

        for i in 0..old_count {
            transforms.push(mm.get_instance_transform_2d(i));
        }

        // Resize (clears internal buffers in Godot)
        mm.set_instance_count(new_count);

        // Restore old transforms
        for i in 0..old_count {
            mm.set_instance_transform_2d(i, transforms[i as usize]);
        }

        // Add new instance
        mm.set_instance_transform_2d(old_count, transform);
    }

    /// Bulk set transforms for a MultiMesh
    pub fn set_multimesh_transforms_2d(
        mut multimesh: Gd<MultiMesh>,
        transforms: &[Transform2D],
        t_count: i32,
    ) {
        let count = t_count.min(transforms.len() as i32);

        for i in 0..count {
            multimesh.set_instance_transform_2d(i, transforms[i as usize]);
        }
    }

    /// Path length
    pub fn get_path_length(points: PackedVector2Array) -> f32 {
        let len = points.len();
        if len < 2 {
            return 0.0;
        }

        let mut total = 0.0;

        for i in 0..(len - 1) {
            let a = points.get(i);
            let b = points.get(i + 1);
            total += a.expect("already checked previously").distance_to(b.expect("checked via len"));
        }

        total
    }

    /// Recursive leaf collection
    pub fn get_node_leaves(node: Gd<Node>) -> Array<Gd<Node>> {
        let mut leaves = Array::new();

        let child_count = node.get_child_count();

        if child_count == 0 {
            leaves.push(&node);
            return leaves;
        }

        for i in 0..child_count {
            let child = node.get_child(i);

            let child_leaves = Self::get_node_leaves(child.expect("child count says yes"));
            for leaf in child_leaves.iter_shared() {
                leaves.push(&leaf);
            }
        }

        leaves
    }

    /// Simple line mesh (GL_LINES style)
    #[func]
    pub fn create_line_mesh_2d(line_points: PackedVector2Array) -> Gd<ArrayMesh> {
        let mut mesh = ArrayMesh::new_gd();

        if line_points.len() < 2 {
            return mesh;
        }

        if line_points.len() % 2 != 0 {
            godot_print!("create_line_mesh_2d called with uneven point number!");
        }

        let mut arrays = VarArray::new();

        // No resize needed
        arrays.push(&line_points.to_variant());

        mesh.add_surface_from_arrays(PrimitiveType::LINES, &arrays);

        mesh
    }

    /// Thick line mesh built from quads (triangle strips per segment)
    #[func]
    pub fn create_line_mesh_from_lines(
        lines: PackedVector2Array,
        vertex_start_width: f32,
        vertex_end_width: f32,
    ) -> Option<Gd<ArrayMesh>> {
        if lines.len() < 2 {
            return None;
        }

        let mut verts: Vec<Vector2> = Vec::new();
        let mut uvs: Vec<Vector2> = Vec::new();
        let mut colors: Vec<Color> = Vec::new();

        let total_segments = lines.len() / 2;

        for i in 0..total_segments {
            let j = i * 2;

            let p0 = lines.get(j).expect("invalid lines given!");
            let p1 = lines.get(j + 1).expect("invalid lines given!");

            let segment_uv = i as f32 / total_segments as f32;

            let width0 = vertex_start_width.lerp(vertex_end_width, segment_uv);
            let width1 = vertex_start_width.lerp(vertex_end_width, (i as f32 + 1.0) / total_segments as f32);

            let dir = (p1 - p0).normalized();
            let normal = Vector2::new(-dir.y, dir.x);

            let v0 = p0 + normal * width0;
            let v1 = p0 - normal * width0;
            let v2 = p1 + normal * width1;
            let v3 = p1 - normal * width1;

            // Two triangles (same as GDScript)
            verts.push(v0);
            verts.push(v1);
            verts.push(v3);

            verts.push(v3);
            verts.push(v2);
            verts.push(v0);

            uvs.push(Vector2::new(1.0, 0.0));
            uvs.push(Vector2::new(0.0, 0.0));
            uvs.push(Vector2::new(0.0, 1.0));

            uvs.push(Vector2::new(0.0, 1.0));
            uvs.push(Vector2::new(1.0, 1.0));
            uvs.push(Vector2::new(1.0, 0.0));

            for _ in 0..6 {
                colors.push(Color::WHITE);
            }
        }

        let mut mesh = ArrayMesh::new_gd();

        let mut arrays = VarArray::new();
        arrays.resize(ArrayType::MAX.ord() as usize, &Variant::nil());

        arrays.set(
            ArrayType::VERTEX.ord() as usize,
            &PackedVector2Array::from(verts.as_slice()).to_variant(),
        );

        arrays.set(
            ArrayType::TEX_UV.ord() as usize,
            &PackedVector2Array::from(uvs.as_slice()).to_variant(),
        );

        arrays.set(
            ArrayType::COLOR.ord() as usize,
            &PackedColorArray::from(colors.as_slice()).to_variant(),
        );

        mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);

        Some(mesh)
    }
}