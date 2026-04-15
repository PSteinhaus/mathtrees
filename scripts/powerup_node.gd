extends Node2D
class_name PowerupNode

enum PowerupVariant {ENERGY, SPEED, DRILL}
var powerup_variant: PowerupVariant
var variant_sprite: Sprite2D
var level: int = 0

func variant_to_texture(variant: PowerupVariant) -> Texture:
	match variant:
		PowerupVariant.ENERGY:	return load("res://sprites/energy.png")
		PowerupVariant.SPEED:	return load("res://sprites/speed.png")
		PowerupVariant.DRILL:	return load("res://sprites/drill.png")
	return load("res://sprites/circle.png")

func _init(variant: PowerupVariant) -> void:
	set_variant(variant)

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
