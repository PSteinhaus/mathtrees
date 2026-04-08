extends Node2D
class_name RT_Tree

@export var root: Line2D
var rt_children: Dictionary[RT_Tree, int] = {}
signal optimize_finished
var is_optimized: bool = false

func _ready() -> void:
	if root == null:
		root = Line2D.new()
		add_child(root)
		root.default_color = Color.WHITE
		root.width = 30.
		root.begin_cap_mode = Line2D.LINE_CAP_ROUND
		root.end_cap_mode = Line2D.LINE_CAP_ROUND
	var default_curve = Curve.new()

	# First point: x = 0, y = 1.0 (start fully visible)
	default_curve.add_point(Vector2(0.0, 1.0))

	# Second point: x = 1, y = 0.0 (almost faded out)
	default_curve.add_point(Vector2(1.0, 0.2))

	# Optional: adjust interpolation for smoother fade (e.g., ease‑out)
	# You can set the interpolation to "bezier" or just tweak tangents.
	default_curve.set_point_left_tangent(0, -0.)  # incoming tangent point 1
	default_curve.set_point_right_tangent(0, 0.)    # outgoing tangent point 1
	default_curve.set_point_left_tangent(1, -0.3)  # incoming tangent point 1
	default_curve.set_point_right_tangent(1, 0.)    # outgoing tangent point 1
	
	set_curve(default_curve)

var opt_cooldown: float = 0.
var optimization_activated: bool = false
var opt_strikes: int = 0
func _process(delta: float) -> void:
	if optimization_activated:
		opt_cooldown -= delta
		const OPTIMIZE_COOLDOWN: float = 0.22
		if opt_cooldown <= 0:
			var points_before = root.get_point_count()
			optimize(false, 50)
			var points_after = root.get_point_count()
			if points_after == points_before:
				opt_strikes += 1
			if opt_strikes >= 2:
				optimization_activated = false
				is_optimized = true
				optimize_finished.emit()
			opt_cooldown = OPTIMIZE_COOLDOWN

func add_point(pos: Vector2) -> void:
	# Adds a point to the root Line2D.
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return
	root.add_point(pos)
	# activate optimization
	is_optimized = false
	optimization_activated = true

func points() -> PackedVector2Array:
	return root.points

func add_rt_child(child: RT_Tree, index: int) -> void:
	# Attaches a child RT_Tree starting at a point of the root.
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return
	if child == null:
		push_warning("RT_Tree: child is null.")
		return
	if index < 0 or index >= root.points.size():
		push_warning("RT_Tree: index out of range.")
		return

	# Position the child at the chosen root point
	var start_pos: Vector2 = root.points[index]
	child.position = start_pos

	# Store in dictionary and add as a child node in the scene tree.
	rt_children[child] = index
	if not child.is_inside_tree():
		add_child(child)

func set_curve(curve: Curve, include_children: bool = true):
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return
	
	root.width_curve = curve
	if include_children:
		for child in rt_children.keys():
			if child != null:
				child.set_curve(curve, true)

## Shrinks down the number of points the Line2D is made up of, at the cost of fidelity
func optimize(include_children: bool, max_points: int = -1, in_place: bool = true):
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return
	
	var points: PackedVector2Array = root.points	# get the points of the current Line2D as a copy
	var new_points: PackedVector2Array = PackedVector2Array()
	var indices_to_delete: Array[int] = []
	var skip: bool = false
	# if max_points is a positive number only so many points should be optimized at max
	# these points are to be taken from the end of the root
	var start_index: int = 0
	if max_points >= 0:
		start_index = clamp(points.size() - max_points, 0, points.size())
		# make sure all points up to there are contained in the new_points
		if not in_place:
			new_points.append_array(points.slice(0,start_index))
	# iterate over all points following the start_index to check them for optimization
	var p0: Vector2 = points[start_index]	# current
	new_points.push_back(p0)
	#print("points before: "+str(points.size()))
	for i: int in (points.size() - start_index - 2):
		var j: int = start_index + i
		if skip:
			skip = false
			continue
		#print("j: "+str(j))
		# get the two following points
		var p1: Vector2 = points[j+1]	# first
		var p2: Vector2 = points[j+2]	# second
		# calculate how far the first point strays from the line between the current and the second point
		var distance_squared: float = Helpers.dist_to_line_squared(p0, p1, p2)
		# if the distance is larger than the required threshold, keep p1, else lose it by continuing with p2
		const DIST_THRESHOLD: float = 2.3
		# exception: if losing p1 would result in an edge that is longer than the CHUNK_SIZE, then keep p1 for technical reasons 
		if distance_squared > DIST_THRESHOLD ** 2 || p0.distance_squared_to(p2) >= RootPointMap.CHUNK_SIZE ** 2:
			p0 = p1
			if not in_place:
				new_points.push_back(p1)
		else:
			skip = true
			p0 = p2
			indices_to_delete.push_back(j+1)
			if not in_place:
				new_points.push_back(p2)
	if in_place:
		indices_to_delete.reverse()
		for i in indices_to_delete:
			root.remove_point(i)
	else:
		# re-add the final point of the path
		new_points.push_back(points[-1]) 
		root.points = new_points
	
	#print("points after: "+str(root.points.size()))
	
	# Optionally recurse into children.
	if include_children:
		for child in rt_children.keys():
			if child != null:
				child.optimize(include_children, max_points, in_place)

func point_count_with_children() -> int:
	var count = root.get_point_count()
	var children_count = 0
	for c: RT_Tree in rt_children.keys():
		children_count += c.point_count_with_children()
	return count + children_count

## Applies a lambda to the widths of points, optionally recursing into rt_children.
func apply_widths(func_lambda: Callable, include_children: bool = true, force_update: bool = false) -> void:
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return

	var points: PackedVector2Array = root.points
	var count: int = points.size()
	if count == 0:
		return

	# Decide how many points to update.
	var start_idx := 0
	const MAX_UPDATED_NODES := 100
	if not force_update and count > MAX_UPDATED_NODES:
		start_idx = count - MAX_UPDATED_NODES

	# Example assumption: lambda takes (index: int, global_index: int) or (index: int) and returns a width (float).
	# Adjust the call signature to your actual needs.
	# FIXME: this currently makes no sense, as the width of a 2DLine is just a single float... the code is only kept here in case I ever build a custom thing based on MultiMeshInstance instead of 2DLine
	for i in range(start_idx, count):
		var width_val = func_lambda.call(i, count)
		# Line2D has a single width property, and optionally a per-point width array in Godot 4 via the 'width' and 'width_curve',
		# so here we just set the global width. Adapt if you store widths differently.[web:1][web:7]
		if typeof(width_val) == TYPE_FLOAT or typeof(width_val) == TYPE_INT:
			root.width = float(width_val)

	# Optionally recurse into children.
	if include_children:
		for child in rt_children.keys():
			if child != null:
				child.apply_widths(func_lambda, include_children, force_update)
