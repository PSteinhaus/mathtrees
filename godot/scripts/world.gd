extends Node2D
class_name World

var is_touching := false
@onready var camera: Camera2D = $Camera2D
var current_touch_screen
const GROW_DELAY := .00
var grow_cooldown := 0.
var root_point_map := RootPointMap.new()
var boulder_map := BoulderMap.new()
var power_nodes: Array[PowerupNode] = []
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

static var opt_enabled: bool = false
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
			# also place some energy boulders
			if randi_range(0, 100) < 12:
				var x: float = chunk_x * CHUNK_SIZE + randf() * CHUNK_SIZE
				var y: float = chunk_y * CHUNK_SIZE + randf() * CHUNK_SIZE
				var size: float = randf_range(0.8, 1.2)
				var variant = PowerupNode.PowerupVariant.values().pick_random()
				boulder_map.generate_power_boulder_at(root_pos + Vector2(x, y), size, variant)

func _init() -> void:
	# register yourself as THE WORLD on the globalton
	Global.set_world(self)

func _ready() -> void:
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
	#$RT_Tree_Up.position = root_pos
	#$RT_Tree_Up.add_point(Vector2(0., 0.))
	#$RT_Tree_Up.add_point(Vector2(0., -100.))
	## add branches
	#var branch0 = RT_Tree.new()
	#var branch1 = RT_Tree.new()
	#$RT_Tree_Up.add_rt_child(branch0, 1)
	#$RT_Tree_Up.add_rt_child(branch1, 1)
	#branch0.add_point(Vector2(0., 0.))
	#branch0.add_point(Vector2(-40., -50.))
	#branch1.add_point(Vector2(0., 0.))
	#branch1.add_point(Vector2(50., -50.))
	#branch1.add_point(Vector2(80., -160.))
	##var branch2 = RT_Tree.new()
	##var branch3 = RT_Tree.new()
	##branch1.add_rt_child(branch2, 1)
	##branch1.add_rt_child(branch3, 1)
	##branch2.add_point(Vector2(0., 0.), false)
	##branch2.add_point(Vector2(30., -50.), false)
	##branch3.add_point(Vector2(0., 0.), false)
	##branch3.add_point(Vector2(-30., -50.), false)
	#var g_scale = Vector2(0.6, 0.6)
	#$RT_Tree_Up.grow_recursively(g_scale)
	#for c in $RT_Tree_Up.rt_children:
		#c.grow_recursively(g_scale)
	#for c in $RT_Tree_Up.rt_children:
		#for c0 in c.rt_children:
			#c0.grow_recursively(g_scale)
	#for c in $RT_Tree_Up.rt_children:
		#for c0 in c.rt_children:
			#for c1 in c0.rt_children:
				#c1.grow_recursively(g_scale)
	#for c in $RT_Tree_Up.rt_children:
		#for c0 in c.rt_children:
			#for c1 in c0.rt_children:
				#for c2 in c1.rt_children:
					#c2.grow_recursively(g_scale)
	#$RT_Tree_Up.scale *= 1.8
	
	var k = FracKernel.new()
	k.add_point(Vector2(-40., -50.))
	k.add_point(Vector2(-70., -110.))
	var k_branch0 = k.start_child_arm_from(0, Vector2(50., -50.))
	k_branch0.add_point(Vector2(80., -120.))
	$FractalTree.kernel = k
	$FractalTree.position = root_pos
	#var tween = create_tween()
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	#tween.tween_interval(1.25)
	#tween.tween_callback($FractalTree.grow)
	
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
	var c_rect = camera.camera_global_rect()
	var boulder_rect = Rect2i(boulder_map.global_to_coordinate(c_rect.position), boulder_map.global_to_coordinate(c_rect.size))
	if boulder_rect != cached_boulder_rect:
		#print("RECALC "+str(randi()))
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
	var current_touch_global = camera.screen_to_world(current_touch_screen)
	var current_touch_local = current_tree.to_local(current_touch_global)
	var grow_vec: Vector2 = current_touch_local - latest_point
	# grow into the direction of the touch, but only as far as permitted per second
	const GROW_PER_SECOND: float = 170.
	const CLOSE_FACTOR: float = 4.
	grow_vec = grow_vec.limit_length(delta * GROW_PER_SECOND * CLOSE_FACTOR * energy_grow_factor())
	# also: stop if you hit a boulder
	var end_temp_global = current_tree.to_global(latest_point + grow_vec)
	var farthest_allowed_global = boulder_map.closest_allowed_point(latest_root_point_global(), end_temp_global, true)
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
	var global_pos = camera.screen_to_world(screen_pos)
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

func react_to_new_boulder_powerup_discovery(b: BoulderPowerup) -> void:
	b.react_to_discovery()
	# get the points of the currently growing root and then use a tween to move the boulder along
	# these points back up to the tree where it is placed in a free spot and set to "discovered"
	# so that it gets available for exercise interaction
	var points: PackedVector2Array = current_tree.points_global()
	points.reverse()
	const SPEED: float = 130.
	var tween = Helpers.move_along_points(b.powerup_node, points, SPEED)
	# when the powerup_node reaches the root, find a free spot near the root with enough space around and move it there
	var free_spot: Vector2 = find_free_spot_at_root()	# FIXME: this call (or something else?) sometimes causes weird bugs where multiple power_nodes are suddenly discovery-affected (moved along the path and for each one a new placed position is found...)
	var r_pos: Vector2 = $RT_Tree.position
	tween = Helpers.move_to_point(b.powerup_node, tween, r_pos, free_spot, r_pos.distance_to(free_spot) / SPEED)
	tween.tween_callback(
			func() -> void: b.powerup_node.state = PowerupNode.State.PLACED
		)
	b.powerup_node.placed_pos = free_spot

var rad_offset: float = 0.		# to save where the last run of the algorithm left
var angle_offset: float = 0.	# in order not to unnecessarily run the first steps again
func find_free_spot_at_root() -> Vector2:
	# set a radius close to the root (meaning small) and then cycle through angles until you find one
	# that is free
	const INITIAL_RADIUS: float = 150.
	const ANGLE_BORDER: float = 0.3
	const INITIAL_ANGLE: float = PI - ANGLE_BORDER
	const MIN_ANGLE: float = ANGLE_BORDER
	const ANGLE_STEP: float = - 0.2
	const RADIUS_STEP: float = 64.
	const CLOSE_THRESHOLD_SPOT: float = 160.
	const MAX_RAD: float = 1500.
	var free_spot: Vector2 = Vector2.ZERO
	var angle: float = INITIAL_ANGLE + angle_offset
	var rad: float = INITIAL_RADIUS + rad_offset
	
	var iterate: bool = false
	while free_spot == Vector2.ZERO:
		if iterate:
			angle += ANGLE_STEP
			if angle < MIN_ANGLE:
				angle = INITIAL_ANGLE
				rad += RADIUS_STEP
				if rad > MAX_RAD:
					# emergency fallback in case anyone should ever have so many powerups that no new positions can be found...
					return $RT_Tree.position + Vector2(400. + randf_range(- 150., 150.), 30. + randf_range(- 150., 150.))
			iterate = false
		
		var spot: Vector2 = $RT_Tree.position + Vector2(rad * cos(angle), rad * sin(angle))
		# the spot is considered free if the distance to other power nodes (and boulders) is larger than a threshold
		var closest_b_face_dist_squared = boulder_map.closest_boulder_face_dist_sq_global(spot)
		if closest_b_face_dist_squared <= 2 ** 2.:
			iterate = true
		if iterate: continue
		# if you passed the boulders check the power nodes next
		for n: PowerupNode in power_nodes:
			if n.state == PowerupNode.State.PLACED || n.state == PowerupNode.State.MOVING:
				# only nodes with paced positions should be considered for collision
				var dist_squared: float = spot.distance_squared_to(n.placed_pos)
				if dist_squared <= CLOSE_THRESHOLD_SPOT ** 2.:
					iterate = true
					break
		if iterate: continue
		free_spot = spot
	
	rad_offset = rad - INITIAL_RADIUS
	angle_offset = angle - INITIAL_ANGLE
	return free_spot

func add_power_up_node(node: PowerupNode) -> void:
	add_child(node)
	power_nodes.push_back(node)

func engage_exercise_from_boulder_powerup(b: BoulderPowerup) -> void:
	pass


func _on_ex_zr_20_answer_checked(correct: bool) -> void:
	# get a new challenge
	if correct:
		%ExZR20.new_challenge()


func _on_ex_zr_20_level_changed(_old_level: int, _new_level: int) -> void:
	$FractalTree.grow()
