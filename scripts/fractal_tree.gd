extends MultiMeshInstance2D
class_name FractalTree

# the mesh and texture for one segment
# multimesh: MultiMesh

# the following defines the structure of the fractal kernel
class FracKernel:	
	## the first point is explicitly (0., 0.)
	var core_arm: Array[Vector2] = [Vector2(0., 0.)]
	## a nested structure of a child kernels and at which point of the core_arm they attach
	var child_arms: Dictionary[FracKernel, int]
	
	func add_point(pos: Vector2) -> void:
		core_arm.push_back(pos)
	
	func add_child(k: FracKernel, index: int) -> void:
		child_arms[k] = index
	
	func start_child_arm_from(start_index: int, relative_pos: Vector2) -> FracKernel:
		var new_arm: FracKernel = FracKernel.new()
		# the position is relative to the point of our core_arm where it starts
		new_arm.add_point(relative_pos)
		add_child(new_arm, start_index)
		return new_arm
	
	func get_lines() -> PackedVector2Array:
		var lines: PackedVector2Array = []
		# first find the points of the core_arm
		for i: int in range(core_arm.size() - 1):
			lines.push_back(core_arm[i])
			lines.push_back(core_arm[i+1])
		for c in child_arms.keys():
			var i: int = child_arms[c]
			var start: Vector2 = core_arm[i]
			var local_lines: PackedVector2Array = c.get_lines()
			for l in local_lines:
				lines.push_back(start + l)
		return lines
	
	func get_leaves() -> Array[Vector2]:
		var leaves: Array[Vector2] = []
		# first find the end of the core_arm
		var end_index: int = core_arm.size() - 1
		if !child_arms.values().any(func(i): return i == end_index):
			# the tip has no children, so its actually a leaf
			leaves.push_back(core_arm[end_index])
		for c in child_arms.keys():
			var i: int = child_arms[c]
			var start: Vector2 = core_arm[i]
			var local_leaves: Array[Vector2] = c.get_leaves()
			for l in local_leaves:
				leaves.push_back(start + l)
		return leaves
	
	func get_leave_rotations() -> Array[float]:
		var rots: Array[float] = []
		# first find the end of the core_arm
		var end_index: int = core_arm.size() - 1
		if !child_arms.values().any(func(i): return i == end_index):
			# the tip has no children, so its actually a leaf
			# if there is more than one point to this arm, then it has a direction
			if end_index > 0:
				rots.push_back(core_arm[end_index-1].angle_to_point(core_arm[end_index]) + PI / 2.)
			else:
				rots.push_back(0.)
		for c in child_arms.keys():
			var local_rots: Array[float] = c.get_leave_rotations()
			for r in local_rots:
				rots.push_back(r)
		return rots

func _ready() -> void:
	# initialize ghost tree and add it straight to the world (as it should be totally unmoved by anything
	ghost_tree = Node2D.new()
	Global.get_world().add_child.call_deferred(ghost_tree)
	
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = Helpers.create_convex_polygon_mesh_2d(PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2(-0.5, 0.5),
		Vector2(0.5, -0.5),
		Vector2(0.5, 0.5)
	]))

# currently unnecessary; reactivate if we add swayug´
func _process(_delta: float) -> void:
	update_multimesh_transforms()

func update_mesh_for_kernel() -> void:
	var lines: PackedVector2Array = kernel.get_lines()
	# around each point place some points to build our final mesh from
	var line_mesh: Mesh = Helpers.create_line_mesh_from_lines(lines)
	multimesh.mesh = line_mesh
	update_multimesh_transforms()

var kernel: FracKernel:
	get: return kernel
	set(new_kernel):
		kernel = new_kernel
		# calculate the mesh for the multimesh based upon this kernel
		update_mesh_for_kernel()
## This tree models how the tree of kernels that we want to draw using the Multimesh
## Each node in this tree represents a kernel
## The node's position represents the starting point relative to the parent
## The node's scale represents the scale relative to parent, the rotation represents the rot relative to parent
## This is a ghost tree as it renders to nothing; instead, we use it to make use of Godots wonderful node tree
## system to give us Transform2Ds that we can use to draw instances of our Multimesh
var ghost_tree: Node2D

## grow the fractal tree by one iteration, based on the kernel
func grow() -> void:
	if kernel == null or ghost_tree == null:
		return

	var kernel_leaves: Array[Vector2] = kernel.get_leaves()
	var kernel_rots: Array[float] = kernel.get_leave_rotations()
	var node_leaves: Array[Node] = Helpers.get_node_leaves(ghost_tree)

	for node in node_leaves:
		for i: int in range(kernel_leaves.size()):
			var leaf_node := SwayNode2D.new()
			var leaf_pos = kernel_leaves[i]
			var leaf_rot = kernel_rots[i]
			leaf_node.position = leaf_pos
			const CHILD_SCALE: float = 0.7
			leaf_node.scale = Vector2(CHILD_SCALE, CHILD_SCALE)
			leaf_node.rotation = leaf_rot
			leaf_node.original_rot = leaf_rot	# for swaying in the wind, see SwayNode2D
			leaf_node.phase_shift =  leaf_rot * 2.	# for swaying in the wind, see SwayNode2D; also: randf() * TAU makes the tree appear sick ;)
			node.add_child(leaf_node)
	update_multimesh_transforms()

## iterates through the kernel to translate all its arm segments into transform2Ds of the segment
## given in the mm Multimesh
## FIXME: if I ever want to optimize stuff, this is in heavy use and could easily be turned into Rust 
func get_global_transforms() -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	var stack: Array[Node2D] = [ghost_tree]

	while stack.size() > 0:
		var node: Node2D = stack.pop_back()
		result.append(node.global_transform)	# if we wanted to optimize this further we would not calc the global_transforms here on the CPU
												# and leave it to the GPU, by using a custom shader using the tree structure to multiply transforms (but this is probably overengineering...)

		for c in node.get_children():
			stack.append(c)

	return result

func update_multimesh_transforms() -> void:
	var transforms: Array[Transform2D] = get_global_transforms()
	multimesh.instance_count = transforms.size()
	Helpers.set_multimesh_transforms_2d(multimesh, transforms, transforms.size())
