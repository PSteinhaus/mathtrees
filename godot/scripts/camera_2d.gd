extends Camera2D

@export var target: Vector2			# The node/point to follow
@export var follow_speed := 0.90	# Bigger = snappier, smaller = more floaty

@export var zoom_speed := 0.02
@export var min_zoom := 0.25
@export var max_zoom := 5.0

var touches := {}

var last_pinch_distance := 0.0
var last_pinch_center := Vector2.ZERO

func _physics_process(delta: float) -> void:
	if target == null:
		return

	global_position = global_position.lerp(target, follow_speed * delta)

func _input(event: InputEvent) -> void:
	# Touch pressed/released
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)

			if touches.size() < 2:
				last_pinch_distance = 0.0

	# Touch moved
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position

		if touches.size() == 2:
			_handle_pinch()


func _handle_pinch() -> void:
	var positions = touches.values()

	var p1: Vector2 = positions[0]
	var p2: Vector2 = positions[1]

	# Current pinch center in screen coordinates
	var pinch_center = (p1 + p2) * 0.5

	# Current finger distance
	var current_distance = p1.distance_to(p2)

	# First frame of pinch
	if last_pinch_distance <= 0.0:
		last_pinch_distance = current_distance
		last_pinch_center = pinch_center
		return

	# World position under pinch center BEFORE zoom
	var world_before = screen_to_world(pinch_center)

	# Calculate zoom
	var delta_distance = current_distance - last_pinch_distance
	var zoom_factor = 1.0 + delta_distance * zoom_speed

	var new_zoom = zoom * zoom_factor

	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)

	zoom = new_zoom

	# World position under pinch center AFTER zoom
	var world_after = screen_to_world(pinch_center)

	# Move target so the world point under the fingers stays fixed
	target += world_before - world_after

	last_pinch_distance = current_distance
	last_pinch_center = pinch_center


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var inv = get_canvas_transform().affine_inverse()
	return inv * screen_pos


func camera_global_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size * 0.5 * zoom
	var center = global_position
	var top_left = center - half_size

	return Rect2(top_left, half_size * 2.0)
