use godot::prelude::*;

pub mod fractal_tree;
pub mod frac_kernel;
pub mod sway_node_2d;
mod ghost_node;
mod ghost_tree;
pub mod optimized_helpers;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}