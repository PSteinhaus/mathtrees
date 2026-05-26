extends Node

@onready var camera: Camera2D = %Camera2D

func _process(_delta):
	if camera == null:
		return

	var inv_zoom = Vector2.ONE / camera.zoom
	%ExZR20.scale = inv_zoom

	# Desired screen-space position
	var screen_pos = Vector2.ZERO

	# Convert screen-space -> world-space
	%ExZR20.global_position = camera.screen_to_world(screen_pos)
