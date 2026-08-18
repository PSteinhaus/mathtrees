extends Node2D
class_name PowerupNode

enum PowerupVariant {ENERGY, SPEED, DRILL}
var powerup_variant: PowerupVariant
var variant_sprite: Sprite2D
var boulder_sprite: Sprite2D
var boulder: BoulderPowerup
var placed_pos: Vector2

## Persistent level of this powerup.
## This is authoritative; the associated Exercise mirrors it while active.
var level: int = 0
var active_exercise: Exercise = null

enum State {UNDISCOVERED, MOVING, PLACED}
var state: State = State.UNDISCOVERED

#func _process(delta: float) -> void:
	#if boulder.state == boulder.State.MOVING:
		## make it follow you
		##boulder.move_visually(position)

func variant_to_texture(variant: PowerupVariant) -> Texture:
	match variant:
		PowerupVariant.ENERGY:	return load("res://sprites/energy.png")
		PowerupVariant.SPEED:	return load("res://sprites/speed.png")
		PowerupVariant.DRILL:	return load("res://sprites/drill.png")
	return load("res://sprites/circle.png")

func _init(variant: PowerupVariant, b: BoulderPowerup) -> void:
	boulder = b
	boulder_sprite = Sprite2D.new()
	boulder_sprite.texture = load("res://sprites/small_boulder.png")
	add_child(boulder_sprite)
	set_variant(variant)
	set_colors(b.color, Color.BLACK, Color.WHITE)

var boulder_color : Color
var background_color : Color
var highlight_color : Color
func set_colors(boulder_c: Color, background_c: Color, highlight_c: Color) -> void:
	boulder_color = boulder_c
	boulder_sprite.self_modulate = boulder_c
	background_color = background_c
	variant_sprite.self_modulate = background_c
	highlight_color = highlight_c

func cleanup_variant() -> void:
	if variant_sprite != null:
		variant_sprite.queue_free()

func set_variant(variant: PowerupVariant) -> void:
	cleanup_variant()
	powerup_variant = variant
	# create a sprite node for the variant
	variant_sprite = Sprite2D.new()
	variant_sprite.texture = variant_to_texture(variant)
	#variant_sprite.self_modulate = Color.BLACK
	add_child(variant_sprite)

func react_to_discovery():
	state = State.MOVING
	variant_sprite.self_modulate = highlight_color

func begin_exercise(exercise: Exercise) -> void:
	if active_exercise != null:
		return

	active_exercise = exercise
	exercise.level_changed.connect(_on_exercise_level_changed)
	exercise.level = level
	exercise.new_challenge()

func end_exercise() -> void:
	if active_exercise == null:
		return

	if active_exercise.level_changed.is_connected(_on_exercise_level_changed):
		active_exercise.level_changed.disconnect(_on_exercise_level_changed)

	active_exercise = null

func _on_exercise_level_changed(_old_level: int, new_level: int) -> void:
	level = new_level
