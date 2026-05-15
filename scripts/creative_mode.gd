extends Node2D

@onready var frac_tree: FractalTree = %FractalTree
@onready var bg: MeshInstance2D = %MeshInstanceBG
@onready var music: AudioStreamPlayer = %Music

var new_activated: bool = false

var color_ground: Color
var color_bg: Color
var color_tree: Color

var palette_index: int = 0

func _ready() -> void:
	#var palette = Helpers.generate_palette(Helpers.PaletteStyle.values().pick_random())
	set_palette(Helpers.gacha_palette())
	regenerate_kernel()
	
	%Button_new.visible = false
	
	#var k = FractalTree.FracKernel.new()
	#k.add_point(Vector2(-40., -50.))
	#k.add_point(Vector2(-70., -110.))
	#var k_branch0 = k.start_child_arm_from(0, Vector2(50., -50.))
	#k_branch0.add_point(Vector2(80., -120.))
	#%FractalTree.kernel = k

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			palette_index +=1
			set_palette(Helpers.gacha_palette(palette_index))
			print("set palette to index: "+str(palette_index))
		elif event.keycode == KEY_F:
			regenerate_kernel()

func regenerate_kernel() -> void:
	print("regenerated kernel")
	frac_tree.generate_kernel()


func _on_ex_zr_20_level_changed(old_level: int, new_level: int) -> void:
	frac_tree.grow()

func _on_ex_zr_20_answer_checked(correct: bool) -> void:
	# get a new challenge
	if correct:
		if randi_range(0,1) == 0:
			%Pling2.play()
		else:
			%Pling1.play()
		%ExZR20.new_challenge()
		new_activated = true
		%Button_new.visible = true

func set_palette(palette: Array[Color]):
	color_bg = palette[0]
	color_ground = palette[1]
	color_tree = palette[2]
	
	%MeshInstance2D.self_modulate = color_ground
#	%MeshInstance2D2.self_modulate = color_ground
	frac_tree.self_modulate = color_tree
	bg.self_modulate = color_bg
	
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
