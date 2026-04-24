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

var kernel: FracKernel

## iterates through the kernel to translate all its arm segments into transform2Ds of the segment
## given in the mm Multimesh
func get_transforms() -> Array[Transform2D]:
	
