extends Node2D

var is_touching := false
var current_touch_screen
const GROW_DELAY := .00
var grow_cooldown := 0.
var root_point_map := RootPointMap.new()
@onready var current_tree: RT_Tree = $RT_Tree:
	set(new_value):
		# TODO: add a listener to the old tree merging points with other roots once the run and the optimization is through
		#current_tree.optimize_finished.connect()
		tween_merge_root_points(current_tree, 0)
		current_tree = new_value
		current_tree.optimize_finished.connect(tween_merge_root_points.bind(new_value))
		to_merge_indices = []
	get:
		return current_tree

var energy: float = 1.
const ENERGY_DRAIN_PER_LENGTH: float = 0.0009

func energy_grow_factor() -> float:
	return 1 - ((1 - energy) * 0.98) ** 1.5
func energy_color() -> Color:
	return lerp(Color.DIM_GRAY, Color.WHITE, energy)

# TODO: use this
var to_merge_indices = []

static var opt_enabled: bool = true
func tween_merge_root_points(rt: RT_Tree, offset: int = 50):
	if not opt_enabled: return
	var points = rt.points()
	var s = points.size() - offset
	if s <= 0: return
	for i in range(s):
		var p = rt.to_global(points[i])
		var closest_point: Vector2 = root_point_map.closest_point(p, rt)
		var dist = closest_point.distance_squared_to(p)
		if dist < CLOSE_THRESHOLD && !to_merge_indices.has(i):
			print("optimizing: "+str(i))
			to_merge_indices.push_back(i)
			var c_point = rt.to_local(closest_point)
			var tween := create_tween()
			tween.tween_method(
				func(lerp_p: Vector2):
					rt.root.set_point_position(i, lerp_p),
				points[i],
				c_point,
				1.0
			)
			print("c_point: "+str(c_point))

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var cam := $Camera2D        # or get_viewport().get_camera_2d()
	var inv = cam.get_canvas_transform().affine_inverse()
	return inv * screen_pos

func _ready() -> void:
	$RT_Tree.add_point(Vector2(0., 0.))
	$RT_Tree.add_point(Vector2(120., 200.))
	$RT_Tree.add_point(Vector2(-10., 300.))
	$RT_Tree.add_point(Vector2(0., 350.))

func set_root_point_global(index: int, p: Vector2):
	var p_local = current_tree.to_local(p)
	current_tree.root.set_point_position(index, p_local)
func latest_root_point_local():
	return current_tree.root.points[-1]
func latest_root_point_global():
	return current_tree.root.to_global(latest_root_point_local())

func _process(delta: float) -> void:
	grow_cooldown -= delta
	if is_touching && grow_cooldown <= 0 && current_tree != null:
		grow_towards_touch(delta)
		
	Global.debug_print_string = str(current_tree.root.get_point_count()) + "\n" + str($RT_Tree.point_count_with_children())

const CLOSE_THRESHOLD: float = 50. ** 2
func grow_towards_touch(delta: float) -> void:
	if energy <= 0:
		return
	grow_cooldown = 0
	var latest_point: Vector2 = latest_root_point_local()
	# Convert from screen to world, then to target_node local
	var current_touch_local = current_tree.to_local(screen_to_world(current_touch_screen))
	var grow_vec: Vector2 = current_touch_local - latest_point
	# grow into the direction of the touch, but only as far as permitted per second
	const GROW_PER_SECOND: float = 170.
	# if you want to grow towards an already existing part of another root then you can have more max speed
	var latest_point_global: Vector2 = latest_root_point_global()
	const CLOSE_FACTOR: float = 4.
	if root_point_map.dist_to_closest_line_squared(latest_point_global, current_tree) < CLOSE_THRESHOLD:
		grow_vec = grow_vec.limit_length(delta * GROW_PER_SECOND * CLOSE_FACTOR * energy_grow_factor())
		const CLOSE_DRAIN_FACTOR: float = 0.7
		energy -= grow_vec.length() * ENERGY_DRAIN_PER_LENGTH  * CLOSE_DRAIN_FACTOR
		# TODO: if the latest point is so close make it merge (via a tween) with the closest point and mark it as "to_merge"
		# if the previous point is not "to_merge" (so this one is the first to merge), then keep it
		# if the previous point is already "to_merge" delete the point entirely (later when the root is finished)
		# while going through the "to_merge" points like this find the last "to_merge" point of the chain, and at that point attach the remaining root tail as a new RT_Tree 
	else:
		grow_vec = grow_vec.limit_length(delta * GROW_PER_SECOND * energy_grow_factor())
		energy -= grow_vec.length() * ENERGY_DRAIN_PER_LENGTH
	
	current_tree.root.default_color = energy_color()
	current_tree.add_point(latest_point + grow_vec)
	grow_cooldown += GROW_DELAY

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			is_touching = true
			_update_touch_local(touch_event.position)
		else:
			is_touching = false

	elif event is InputEventScreenDrag and is_touching:
		_update_touch_local(event.position)

func _update_touch_local(screen_pos: Vector2) -> void:
	current_touch_screen = screen_pos
	var global_pos = screen_to_world(screen_pos)
	var latest_point = latest_root_point_global()
	if latest_point == null:
		$Camera2D.target = global_pos
		return
	var diff: Vector2 = global_pos - latest_point
	const MAX_DIFF: float = 150.
	$Camera2D.target = latest_point + diff.limit_length(MAX_DIFF)

func _on_button_pressed() -> void:
	# add the now finished root to the root map:
	root_point_map.update_root_when_optimized(current_tree)
	energy = 1.
	# create a new root starting from the same start
	current_tree = RT_Tree.new()
	$RT_Tree.add_rt_child(current_tree, 0)
	current_tree.add_point(Vector2.ZERO)
	$Camera2D.target = $RT_Tree.global_position


func _on_button_opt_pressed() -> void:
	opt_enabled = !opt_enabled
