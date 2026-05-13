extends Node2D

var color_ground: Color
var color_bg: Color
var color_tree: Color

func _ready() -> void:
	#var palette = Helpers.generate_palette(Helpers.PaletteStyle.values().pick_random())
	var palette = Helpers.gacha_palette()
	color_bg = palette[0]
	color_ground = palette[1]
	color_tree = palette[2]
	
	%MeshInstance2D.self_modulate = color_ground
	%FractalTree.self_modulate = color_tree
	%MeshInstanceBG.self_modulate = color_bg
	
	var k = FractalTree.FracKernel.new()
	k.add_point(Vector2(-40., -50.))
	k.add_point(Vector2(-70., -110.))
	var k_branch0 = k.start_child_arm_from(0, Vector2(50., -50.))
	k_branch0.add_point(Vector2(80., -120.))
	%FractalTree.kernel = k
	%FractalTree.grow()
	%FractalTree.grow()
	%FractalTree.grow()
	%FractalTree.grow()
	

func _on_ex_zr_20_level_changed(old_level: int, new_level: int) -> void:
	%FractalTree.grow()

func _on_ex_zr_20_answer_checked(correct: bool) -> void:
	# get a new challenge
	if correct:
		%ExZR20.new_challenge()
