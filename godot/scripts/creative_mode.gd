extends Node2D

@onready var frac_tree: FractalTreeOptimized = %FractalTree
@onready var bg: MeshInstance2D = %MeshInstanceBG
@onready var music: AudioStreamPlayer = %Music
@onready var camera: Camera2D = $Camera2D

enum State {
	CREATING_TREE,
	GROWING_TREE,
}
var state: State = State.GROWING_TREE:
	set(new_state):
		%ButtonCreateTree.hide()
		%Button_new.hide()
		%ButtonCreateTree.hide()
		%ButtonCreateTreeEnd.hide()
		# things that should always happen
		match new_state:
			State.CREATING_TREE:
				%ExZR20.hide()
				%CreateTreeLabel.show()
				%FractalTree.clear_kernel()
				%ButtonCreateTreeEnd.show()
			State.GROWING_TREE:
				%ExZR20.show()
				%CreateTreeLabel.hide()
		# transition specific things
		match state:
			State.CREATING_TREE:
				match new_state:
					State.CREATING_TREE: pass
					State.GROWING_TREE: pass
			State.GROWING_TREE:
				match new_state:
					State.CREATING_TREE: pass
					State.GROWING_TREE: pass
		state = new_state

var new_activated: bool = false

var color_ground: Color
var color_bg: Color
var color_tree: Color

var palette_index: int = 0

func _ready() -> void:
	#var palette = Helpers.generate_palette(Helpers.PaletteStyle.values().pick_random())
	set_palette(Helpers.gacha_palette())
	call_deferred("regenerate_kernel")
	
	%Button_new.visible = false
	%ButtonCreateTree.visible = false
	
	state = State.GROWING_TREE
	
	#var k = FractalTree.FracKernel.new()
	#k.add_point(Vector2(-40., -50.))
	#k.add_point(Vector2(-70., -110.))
	#var k_branch0 = k.start_child_arm_from(0, Vector2(50., -50.))
	#k_branch0.add_point(Vector2(80., -120.))
	#%FractalTree.kernel = k

func _input(event):
	if (event is InputEventScreenDrag or (event is InputEventScreenTouch and !event.canceled)) and event.index == 0:
		var global_touch: Vector2 = camera.screen_to_world(event.position)
		match state:
			State.GROWING_TREE:
				prune_tree_at(global_touch)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			palette_index += 1
			set_palette(Helpers.gacha_palette(palette_index))
			print("set palette to index: "+str(palette_index))
		elif event.keycode == KEY_F:
			regenerate_kernel()
	elif (event is InputEventScreenDrag or (event is InputEventScreenTouch and !event.canceled)) and event.index == 0:
		var global_touch: Vector2 = camera.screen_to_world(event.position)
		match state:
			State.GROWING_TREE:
				prune_tree_at(global_touch)
			State.CREATING_TREE:
				if event is InputEventScreenTouch and !event.is_released():
					create_branch_from_touch_at(global_touch)
		
func regenerate_kernel() -> void:
	print("regenerated kernel")
	frac_tree.generate_kernel()

func create_branch_from_touch_at(global_pos: Vector2) -> void:
	frac_tree.add_branch_at_closest_joint(frac_tree.to_local(global_pos))

func prune_tree_at(global_touch: Vector2) -> void:
	var local_touch: Vector2 = frac_tree.to_local(global_touch)
	var nodes_before: int = frac_tree.node_count()
	var detached_tree: FractalTreeOptimized = frac_tree.detach_closest_subtree_at(local_touch)
	if detached_tree != null:
		# play crunch sound
		var play_pos: float = %Crunch.get_playback_position()
		if play_pos == 0. || play_pos > 0.04:
			%Crunch.play()
			%Crunch.pitch_scale = 1.0 - 0.6 * ((float(detached_tree.node_count()) / nodes_before) ** 0.3)
		# add the detached tree to the scene and add a tween to make it drop in a parabolic curve and then delete it
		print("count: "+str(detached_tree.node_count()))
		print("parent: "+str(detached_tree.get_parent()))
		add_child(detached_tree)
		detached_tree.scale = %FractalTree.scale
		detached_tree.self_modulate = color_tree
		detached_tree.global_position = global_touch
		launch_node(detached_tree)

func _on_ex_zr_20_level_changed(old_level: int, new_level: int) -> void:
	frac_tree.grow()

func _on_ex_zr_20_answer_checked(correct: bool) -> void:
	# get a new challenge
	if correct:
		%Pling2.play()
		%ExZR20.new_challenge()
		new_activated = true
		%Button_new.visible = true
		%ButtonCreateTree.visible = true

func set_palette(palette: Array[Color]):
	color_bg = palette[0]
	color_ground = palette[1]
	color_tree = palette[2]
	
	%MeshInstance2D.self_modulate = color_ground
#	%MeshInstance2D2.self_modulate = color_ground
	frac_tree.self_modulate = color_tree
	bg.self_modulate = color_bg
	%CreateTreeLabel.self_modulate = color_tree
	
	# also: set the progress bar color!
	# but for that first check whether the ground color works as a contrast for both the background and the tree
	var b = %ExZR20.get_progress_bar()
	var col_final = color_ground.lerp(color_bg, 0.5)
	if Helpers.has_good_contrast(col_final, color_bg, 1.1) && Helpers.has_good_contrast(col_final, color_tree, 1.4):
		b.self_modulate = color_ground #color_bg.lightened(0.2)
	else:
		b.self_modulate = color_bg.lightened(0.25)

func _on_button_new_pressed() -> void:
	if new_activated:
		set_palette(Helpers.gacha_palette())
		regenerate_kernel()
		new_activated = false
		%Button_new.visible = false

func _on_button_create_tree_pressed() -> void:
	state = State.CREATING_TREE

func _on_button_create_tree_end_pressed() -> void:
	state = State.GROWING_TREE
	# FIXME: dirty fix for FracKernel registering this touch still to create one more arm:
	

func launch_node(node: Node2D):
	var start_pos := node.global_position
	
	# Initial throw velocity
	var velocity := Vector2(220, -280)

	# Downward acceleration
	var gravity := 750.0

	# Flight duration
	var duration := 3.0

	# Slight random spin
	var target_rotation := node.rotation + deg_to_rad(randf_range(-40, 40))

	var tween := create_tween()
	tween.set_parallel(true)

	# Move on a parabola
	tween.tween_method(
		func(t: float):
			var pos := start_pos
			
			# Horizontal + initial upward impulse
			pos += velocity * t
			
			# Gravity acceleration downward
			pos += Vector2(0, 0.5 * gravity * t * t)

			node.global_position = pos,
		0.0,
		duration,
		duration
	)

	# Rotate slightly during flight
	tween.tween_property(
		node,
		"rotation",
		target_rotation,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Destroy node after flight
	tween.chain().tween_callback(node.queue_free)
