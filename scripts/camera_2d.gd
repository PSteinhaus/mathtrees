extends Camera2D

@export var target: Vector2       # The node/point to follow
@export var follow_speed := 0.90   # Bigger = snappier, smaller = more floaty

func _process(delta: float) -> void:
	if target == null:
		return

	# Smoothly move towards target using linear interpolation (lerp)
	global_position = global_position.lerp(target, follow_speed * delta)
