extends Node2D
class_name World

var is_touching := false
@onready var camera: Camera2D = $Camera2D
var current_touch_screen
const GROW_DELAY := .00
var grow_cooldown := 0.
var root_point_map := RootPointMap.new()
var boulder_map := BoulderMap.new()
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
const ENERGY_DRAIN_PER_LENGTH: float = 0.0004

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
			#print("optimizing: "+str(i))
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
			#print("c_point: "+str(c_point))

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var inv = camera.get_canvas_transform().affine_inverse()
	return inv * screen_pos

func camera_global_rect() -> Rect2:
	var viewport_size = camera.get_viewport_rect().size
	var half_size = viewport_size * 0.5 * camera.zoom
	var center = camera.global_position
	var top_left = center - half_size
	return Rect2(top_left, half_size * 2.)

## initial boulder generation for the whole world (for now)
func generate_boulders():
	const WORLD_RADIUS: float = 18000.	# how far to each side boulders should be generated
	const CHUNK_SIZE: float = 128.
	const START_X: int = int(-WORLD_RADIUS / CHUNK_SIZE)
	const END_X: int = int(WORLD_RADIUS / CHUNK_SIZE)
	const START_Y: int = 0
	const END_Y: int = int(WORLD_RADIUS / CHUNK_SIZE)
	var root_pos = $RT_Tree.position
	for chunk_x in range(START_X, END_X + 1):
		for chunk_y in range(START_Y, END_Y + 1):
			if chunk_y < 4 && abs(chunk_x) < 3:
				continue
			# in each of these chunks spawn some boulders
			var b_count: int = int(randf() * 2.)
			for i in range(b_count):
				var x: float = chunk_x * CHUNK_SIZE + randf() * CHUNK_SIZE
				var y: float = chunk_y * CHUNK_SIZE + randf() * CHUNK_SIZE
				var size: float = randf_range(0.5, 3.)
				boulder_map.generate_boulder_at(root_pos + Vector2(x, y), size)

func _ready() -> void:
	# register yourself as THE WORLD on the globalton
	Global.set_world(self)
	# initialize the boulders
	Boulder.init_boulders(self)
	
	$RT_Tree.add_point(Vector2(0., 0.))
	$RT_Tree.add_point(Vector2(120., 200.))
	$RT_Tree.add_point(Vector2(-10., 300.))
	$RT_Tree.add_point(Vector2(0., 350.))
	
	var root_pos = $RT_Tree.position
	# generate some random boulders, most farther away and bigger
	generate_boulders()
		
	#boulder_map.generate_boulder_at(root_pos + Vector2(200., 400.))
	#boulder_map.generate_boulder_at(root_pos + Vector2(0., 760.))
	#boulder_map.generate_boulder_at(root_pos + Vector2(-220., 450.))
	#boulder_map.generate_boulder_at(root_pos + Vector2(0., 500.))
	
	# create the tree that grows upwards
	$RT_Tree_Up.position = root_pos
	$RT_Tree_Up.add_point(Vector2(0., 0.))
	$RT_Tree_Up.add_point(Vector2(0., -100.))
	# add branches
	var branch0 = RT_Tree.new()
	var branch1 = RT_Tree.new()
	$RT_Tree_Up.add_rt_child(branch0, 1)
	$RT_Tree_Up.add_rt_child(branch1, 1)
	branch0.add_point(Vector2(0., 0.))
	branch0.add_point(Vector2(-40., -50.))
	branch1.add_point(Vector2(0., 0.))
	branch1.add_point(Vector2(50., -50.))
	branch1.add_point(Vector2(80., -160.))
	#var branch2 = RT_Tree.new()
	#var branch3 = RT_Tree.new()
	#branch1.add_rt_child(branch2, 1)
	#branch1.add_rt_child(branch3, 1)
	#branch2.add_point(Vector2(0., 0.), false)
	#branch2.add_point(Vector2(30., -50.), false)
	#branch3.add_point(Vector2(0., 0.), false)
	#branch3.add_point(Vector2(-30., -50.), false)
	var g_scale = Vector2(0.6, 0.6)
	$RT_Tree_Up.grow_recursively(g_scale)
	for c in $RT_Tree_Up.rt_children:
		c.grow_recursively(g_scale)
	for c in $RT_Tree_Up.rt_children:
		for c0 in c.rt_children:
			c0.grow_recursively(g_scale)
	for c in $RT_Tree_Up.rt_children:
		for c0 in c.rt_children:
			for c1 in c0.rt_children:
				c1.grow_recursively(g_scale)
	for c in $RT_Tree_Up.rt_children:
		for c0 in c.rt_children:
			for c1 in c0.rt_children:
				for c2 in c1.rt_children:
					c2.grow_recursively(g_scale)
	$RT_Tree_Up.scale *= 1.8
	
	_update_touch_local(camera.get_screen_center_position())

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
	# make sure only visible boulders are drawn
	update_visible_boulders()
	
	Global.debug_print_string = str(current_tree.root.get_point_count()) + "\n" + str($RT_Tree.point_count_with_children())

var cached_boulder_rect = null
func update_visible_boulders():
	var c_rect = camera_global_rect()
	var boulder_rect = Rect2i(boulder_map.global_to_coordinate(c_rect.position), boulder_map.global_to_coordinate(c_rect.size))
	if boulder_rect != cached_boulder_rect:
		print("RECALC "+str(randi()))
		var visible_boulders = boulder_map.rect_boulders(c_rect)
		Boulder.set_visible_boulders(visible_boulders)
		cached_boulder_rect = boulder_rect

const CLOSE_THRESHOLD: float = 50. ** 2
func grow_towards_touch(delta: float) -> void:
	if energy <= 0:
		return
	grow_cooldown = 0
	var latest_point: Vector2 = latest_root_point_local()
	# Convert from screen to world, then to target_node local
	var current_touch_global = screen_to_world(current_touch_screen)
	var current_touch_local = current_tree.to_local(current_touch_global)
	var grow_vec: Vector2 = current_touch_local - latest_point
	# grow into the direction of the touch, but only as far as permitted per second
	const GROW_PER_SECOND: float = 170.
	const CLOSE_FACTOR: float = 4.
	grow_vec = grow_vec.limit_length(delta * GROW_PER_SECOND * CLOSE_FACTOR * energy_grow_factor())
	# also: stop if you hit a boulder
	var end_temp_global = current_tree.to_global(latest_point + grow_vec)
	var farthest_allowed_global = boulder_map.closest_allowed_point(latest_root_point_global(), end_temp_global)
	var farthest_allowed_local = current_tree.to_local(farthest_allowed_global)
	var skip_cost: bool = false
	if farthest_allowed_global != end_temp_global:
		grow_vec = farthest_allowed_local - latest_point
		const GROW_LENGTH_THRESHOLD: float = 15.
		# FIXME: don't know whether this is the best workaround
		if grow_vec.length() < GROW_LENGTH_THRESHOLD:
			skip_cost = true
	# if you want to grow towards an already existing part of another root then you can have more max speed
	var latest_point_global: Vector2 = latest_root_point_global()
	var energy_cost: float
	if root_point_map.dist_to_closest_line_squared(latest_point_global, current_tree) < CLOSE_THRESHOLD:
		const CLOSE_DRAIN_FACTOR: float = 0.7
		energy_cost = grow_vec.length() * ENERGY_DRAIN_PER_LENGTH  * CLOSE_DRAIN_FACTOR
		# TODO: if the latest point is so close make it merge (via a tween) with the closest point and mark it as "to_merge"
		# if the previous point is not "to_merge" (so this one is the first to merge), then keep it
		# if the previous point is already "to_merge" delete the point entirely (later when the root is finished)
		# while going through the "to_merge" points like this find the last "to_merge" point of the chain, and at that point attach the remaining root tail as a new RT_Tree 
	else:
		grow_vec = grow_vec.limit_length(delta * GROW_PER_SECOND * energy_grow_factor())
		energy_cost = grow_vec.length() * ENERGY_DRAIN_PER_LENGTH
	if not skip_cost:
		if latest_point_global.y < $RT_Tree.position.y:
			const AIR_PENALTY: float = 12.
			energy_cost *= AIR_PENALTY
		energy -= energy_cost
	
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
		camera.target = global_pos
		return
	var diff: Vector2 = global_pos - latest_point
	const MAX_DIFF: float = 150.
	camera.target = latest_point + diff.limit_length(MAX_DIFF)

func _on_button_pressed() -> void:
	# add the now finished root to the root map:
	root_point_map.update_root_when_optimized(current_tree)
	energy = 1.
	# create a new root starting from the same start
	current_tree = RT_Tree.new()
	$RT_Tree.add_rt_child(current_tree, 0)
	current_tree.add_point(Vector2.ZERO)
	camera.target = $RT_Tree.global_position


func _on_button_opt_pressed() -> void:
	opt_enabled = !opt_enabled
