use godot::prelude::*;

struct MyExtension;
mod fractal_tree;
mod frac_kernel;
mod sway_node_2d;
mod ghost_node;
mod ghost_tree;
mod optimized_helpers;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
