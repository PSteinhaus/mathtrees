extends Node2D
class_name SwayNode2D

var original_rot: float
var phase_shift: float
const SWAY_AMP: float = 0.2
const SWAY_FREQ: float = 0.18

func _process(_delta: float) -> void:
	#if SWAY_FREQ != 0.:
		## if the rotation was changed from outside adapt to that
		#var cache_based_rotation = cached_rotation + cached_rot_offset
		#if cache_based_rotation - rotation > 0.00001:
			#cached_rotation = rotation
		var rot_offset: float = SWAY_AMP * sin(SWAY_FREQ * 0.001 * Time.get_ticks_msec() + phase_shift)
		rotation = original_rot + rot_offset
