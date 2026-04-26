extends MultiMeshInstance2D
class_name FractalTree

# the mesh and texture for one segment
var mm: MultiMesh
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
		# the position is relative to us, the parent kernel, but the child needs it as relative to
		# the point of our core_arm where it starts, so calc the difference
		new_arm.add_point(relative_pos)
		add_child(new_arm, start_index)
		return new_arm
	
	func get_leaves() -> Array[Vector2]:
		var leaves: Array[Vector2] = []
		# first find the end of the core_arm
		var end_index: int = core_arm.size() - 1
		if !child_arms.values().any(func(i): i == end_index):
			# the tip has no children, so its actually a leaf
			leaves.push_back(core_arm[end_index])
		for c in child_arms.keys():
			var i: int = child_arms[c]
			var start: Vector2 = core_arm[i]
			var local_leaves: Array[Vector2] = c.get_leaves()
			for l in local_leaves:
				leaves.push_back(start + l)
		return leaves

var kernel: FracKernel
## This tree models how the tree of kernels that we want to draw using the Multimesh
## Each node in this tree represents a kernel
## The node's position represents the starting point relative to the parent
## The node's scale represents the scale relative to parent, the rotation represents the rot relative to parent
## This is a ghost tree as it renders to nothing; instead, we use it to make use of Godots wonderful node tree
## system to give us Transform2Ds that we can use to draw instances of our Multimesh
var ghost_tree: Node2D

## grow the fractal tree by one iteration, based on the kernel
func grow() -> void:
	

## iterates through the kernel to translate all its arm segments into transform2Ds of the segment
## given in the mm Multimesh
func get_transforms() -> Array[Transform2D]:
	
