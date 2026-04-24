extends Node2D
class_name RT_Tree

@export var root: Line2D
var depth: int = 0	# depth inside the tree (how many parents are above)
var rt_children: Dictionary[RT_Tree, int] = {}
signal optimize_finished
var is_optimized: bool = false
@export var sway_frequency: float = 0.	# 0 means the tree does not sway (in an imaginary breeze)
var cached_rotation: float = 0.
var cached_rot_offset: float = 0.

func clone() -> RT_Tree:
	var copy = RT_Tree.new()
	copy.root = Line2D.new()
	copy.root.points = root.points # copied internally by Godot, so no clone needed
	copy.add_child(copy.root)
	# also clone the children recursively
	for rt_child in rt_children.keys():
		var index = rt_children[rt_child]
		var child_copy = rt_child.clone()
		copy.add_rt_child(child_copy, index)
	return copy

func sway_in_the_wind() -> void:
	if sway_frequency != 0.:
		# if the rotation was changed from outside adapt to that
		var cache_based_rotation = cached_rotation + cached_rot_offset
		if cache_based_rotation - rotation > 0.00001:
			cached_rotation = rotation
		const ROT_MAX_OFFSET: float = 0.08
		var rot_offset = ROT_MAX_OFFSET * sin(sway_frequency * 0.001 * Time.get_ticks_msec() + depth * 0.6)
		rotation = cached_rotation + rot_offset
		cached_rot_offset = rot_offset

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
	sway_in_the_wind()
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

func add_point(pos: Vector2, opt: bool = true) -> void:
	# Adds a point to the root Line2D.
	if root == null:
		push_warning("RT_Tree: root is not assigned.")
		return
	root.add_point(pos)
	# activate optimization
	is_optimized = false
	optimization_activated = opt

## The points making up the root in local coordinates
func points() -> PackedVector2Array:
	return root.points

## The points making up the root in local coordinates
func points_global() -> PackedVector2Array:
	var ps: PackedVector2Array = points()
	var g_ps: PackedVector2Array = []
	g_ps.resize(ps.size())
	var i: int = 0
	for p in ps:
		g_ps[i] = root.to_global(p)
		i += 1
	return g_ps

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
	# propagate sway
	child.sway_frequency = sway_frequency
	# set child depth
	child.depth = depth + 1

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
	
	var root_points: PackedVector2Array = root.points	# get the points of the current Line2D as a copy
	var new_points: PackedVector2Array = PackedVector2Array()
	var indices_to_delete: Array[int] = []
	var skip: bool = false
	# if max_points is a positive number only so many points should be optimized at max
	# these points are to be taken from the end of the root
	# also: start only AT the last child, so that we don't have to mess around with rt_children
	#       losing their parent index / having it moved
	var start_index: int
	if rt_children.is_empty():
		start_index = 0
	else:
		start_index = rt_children.values().reduce(func(acc, x):
			return max(acc, x)
		)
	if max_points >= 0:
		start_index = clamp(root_points.size() - max_points, start_index, root_points.size())
		# make sure all points up to there are contained in the new_points
		if not in_place:
			new_points.append_array(root_points.slice(0,start_index))
	# iterate over all points following the start_index to check them for optimization
	var p0: Vector2 = root_points[start_index]	# current
	new_points.push_back(p0)
	#print("points before: "+str(points.size()))
	for i: int in (root_points.size() - start_index - 2):
		var j: int = start_index + i
		if skip:
			skip = false
			continue
		#print("j: "+str(j))
		# get the two following points
		var p1: Vector2 = root_points[j+1]	# first
		var p2: Vector2 = root_points[j+2]	# second
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
		new_points.push_back(root_points[-1]) 
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

## takes the tip children of this root and add them to the tips of all children
func grow_recursively(grow_scale: Vector2 = Vector2.ONE):
	# get the tip children
	var tip_index = root.points.size() - 1
	var tip_children = rt_children.keys().filter(func(child): return rt_children[child] == tip_index)
	# clone them
	var tip_clones = tip_children.map(func(c): return c.clone())
	# find the tips of the children and add them there
	var leaves = get_leaves()
	for rt_tree: RT_Tree in leaves.keys():
		var leaf_tip_index: int = leaves[rt_tree]
		# TODO: add children rotated fitting to the direction of the tip
		var leaf_tip_direction = rt_tree.root_tip_direction()
		for tip_clone: RT_Tree in tip_clones:
			var final_clone = tip_clone.clone()
			rt_tree.add_rt_child(final_clone, leaf_tip_index)
			final_clone.rotation = leaf_tip_direction
			final_clone.scale = grow_scale

func root_tip_direction() -> float:
	var root_size = root.points.size()
	if root_size > 1:
		var last_point = root.points[root_size - 1]
		var previous_point = root.points[root_size - 2]
		var local_direction = (last_point - previous_point).angle() + PI / 2.
		return local_direction
	else:
		return 0. 

## get the tips of this tree, meaning end points of rt_tree roots which have no children at their tips
## these can belong to rt_children, (or even grandchildren etc.)
## the values represent the index of the last point of the tip-childless rt_child
func get_leaves() -> Dictionary[RT_Tree, int]:
	var leaves: Dictionary[RT_Tree, int] = {}
	var tip_index: int = root.points.size() - 1
	if rt_children.values().all(func(index): return index != tip_index):
		# no tip children, so the tip of this root is a leaf as well
		leaves[self] = tip_index
	# recursively search rt_children for tips and add them to the dictionary
	for rt_child in rt_children:
		var child_leaves = rt_child.get_leaves()
		leaves.merge(child_leaves)
	return leaves
