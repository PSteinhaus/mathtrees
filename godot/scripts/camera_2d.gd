extends Camera2D

@export var target: Vector2       # The node/point to follow
@export var follow_speed := 0.90   # Bigger = snappier, smaller = more floaty

func _process(delta: float) -> void:
	if target == null:
		return

	# Smoothly move towards target using linear interpolation (lerp)
	global_position = global_position.lerp(target, follow_speed * delta)

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var inv = get_canvas_transform().affine_inverse()
	return inv * screen_pos

func camera_global_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size * 0.5 * zoom
	var center = global_position
	var top_left = center - half_size
	return Rect2(top_left, half_size * 2.)
