extends Node

var debug_print_string: String = ""
var world: World

func set_world(w: World):
	world = w
func get_world() -> World:
	return world
