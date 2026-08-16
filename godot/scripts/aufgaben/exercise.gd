## interface for all exercises
@abstract class_name Exercise
extends Control

signal ready_to_check(ready_to_check: bool)  # fires to signal that the task can be checked now (all necessary inputs given)
signal answer_checked(correct: bool)  # fires to signal that an answer has been checked and whether it was correct
signal level_changed(old_level: int, new_level: int)  ## the level changed (via level-up or else)

## enum listing all kinds of exercises
enum ExType {
	NO_EXERCISE, # workaround for "null" values right now...
	MULTIPLY,
	VERBAL_TO_SYMBOLIC,
	OVER_TEN,
	COMMA,
	MULTIPLY_STELLEN,
	DIVIDE,
	RECOGNIZE_MULTIPLY,
	ZR_20,
}
var level: int = 0:
	get:
		return level
	set(val):
		var old_level = level
		if old_level != val:
			level = val
			var b = get_progress_bar()
			b.max_value = progress_for_level_up()
			print("set max_value to "+str(progress_for_level_up()))
			b.value = 0.
			progress_target = 0.
			level_changed.emit(old_level, level)

var progress_erosion_per_sec: float = 1.8
var progress_target: float = 0.
const progress_reward: float = 60

## returns how much progress is required for the next level up, depending on the current level
@abstract func progress_for_level_up() -> float

func _ready() -> void:
	set_input_enabled(true)
	get_progress_bar().max_value = progress_for_level_up()

## return the ExType of this exercise
@abstract func exType() -> ExType 
## check the answer and if it fits advance the progress bar target by a constant amount
func check_answer():
	var correct = check_answer_internal()
	print("correct: "+str(correct))
	print("target_before: "+str(progress_target))
	if correct:
		if progress_for_level_up() >= INF:
			# to still show some appreciation for the correct answer set the progress bar to full
			# and flash the color from bright to empty again
			get_progress_bar().max_value = 999.
			skip_advance_progress_bar = true
			var tween = get_tree().create_tween()
			tween.tween_method(set_progress_bar_full_and_to_opacity, 1.0, 0.0, 2.8)
		else:
			progress_target += progress_reward
			if progress_target > progress_for_level_up() + progress_erosion_per_sec * 3:
				progress_target = progress_for_level_up() + 5 + progress_erosion_per_sec * 3
	else:
		var b = get_progress_bar()
		b.value = b.value * 0.3
		progress_target = progress_target * 0.3
		#progress_target = progress_target * 0.3
	print("target_after: "+str(progress_target))
	answer_checked.emit(correct)
## checks whether the given answer is correct
## overwrite to implement answer checking for individual exercise types
@abstract func check_answer_internal() -> bool
## generates a new challenge of this exercise type
@abstract func new_challenge()
## makes the exercise node and most of its children (no longer) receive input
@abstract func set_input_enabled(val: bool)
## gets the progress bar showing the leveling progress
@abstract func get_progress_bar() -> ProgressBar

func set_progress_bar_full_and_to_opacity(opacity: float):
	var b = get_progress_bar()
	b.value = 999.
	b.modulate = Color(1.,1.,1.,opacity)

var skip_advance_progress_bar = false

func advance_progress_bar_towards_goal(delta: float):
	if skip_advance_progress_bar:
		return
	var b = get_progress_bar()
	var current_val = b.value
	const percentage_travelled_per_tick = 0.33
	const tick_duration = 0.3
	var new_val = current_val + (progress_target - current_val) * percentage_travelled_per_tick * (delta / tick_duration)
	if (new_val > progress_target && current_val < progress_target) || (new_val < progress_target && current_val > progress_target):
		new_val = progress_target
	b.value = new_val
	#print("val: "+str(new_val)+"	, b.value: "+str(b.value)+"	, required: "+str(progress_for_level_up()))
	if new_val >= progress_for_level_up():
		level += 1

func _process(delta: float) -> void:
	advance_progress_bar_towards_goal(delta)
	progress_target -= progress_erosion_per_sec * delta
	if progress_target <= 0:
		progress_target = 0

static func from_ex_type(ex_type: ExType) -> Exercise:
	match ex_type:
		ExType.MULTIPLY: return preload("res://scenes/aufgaben/ex_multiply.tscn").instantiate()
		ExType.VERBAL_TO_SYMBOLIC: return preload("res://scenes/aufgaben/ex_verbal_to_sym.tscn").instantiate()
		ExType.OVER_TEN: return preload("res://scenes/aufgaben/ex_over_ten.tscn").instantiate()
		ExType.COMMA: return preload("res://scenes/aufgaben/ex_comma.tscn").instantiate()
		ExType.MULTIPLY_STELLEN: return preload("res://scenes/aufgaben/ex_multiply_stellen.tscn").instantiate()
		ExType.DIVIDE: return preload("res://scenes/aufgaben/ex_divide.tscn").instantiate()
		ExType.RECOGNIZE_MULTIPLY: return preload("res://scenes/aufgaben/ex_recognize_multiply.tscn").instantiate()
		ExType.ZR_20: return preload("res://scenes/aufgaben/ex_zr_20.tscn").instantiate()
		
	push_error("Exercise for unreasonable ex_type requested; type is: "+str(ex_type))
	return null

func get_ziffer_at(num: int, pos: int) -> int:
	var teiler = 10 ** pos
	@warning_ignore("integer_division")
	return (num / teiler) % 10

func ziffer_verbal(num: int, pos: int) -> String:

	match pos:
		0:
			match num:
				0:
					return ""
				1:
					return "ein"
				2:
					return "zwei"
				3:
					return "drei"
				4:
					return "vier"
				5:
					return "fünf"
				6:
					return "sechs"
				7:
					return "sieben"
				8:
					return "acht"
				9:
					return "neun"
				_: return ""
		1:
			match num:
				0:
					return ""
				1:
					return "zehn"
				2:
					return "zwanzig"
				3:
					return "dreißig"
				4:
					return "vierzig"
				5:
					return "fünfzig"
				6:
					return "sechzig"
				7:
					return "siebzig"
				8:
					return "achtzig"
				9:
					return "neunzig"
				_: return ""
		2:
			match num:
				0:
					return ""
				1:
					return "ein"
				2:
					return "zwei"
				3:
					return "drei"
				4:
					return "vier"
				5:
					return "fünf"
				6:
					return "sechs"
				7:
					return "sieben"
				8:
					return "acht"
				9:
					return "neun"
				_: return ""
		3:
			match num:
				0:
					return ""
				1:
					return "ein"
				2:
					return "zwei"
				3:
					return "drei"
				4:
					return "vier"
				5:
					return "fünf"
				6:
					return "sechs"
				7:
					return "sieben"
				8:
					return "acht"
				9:
					return "neun"
				_: return ""
		4:
			match num:
				0:
					return ""
				1:
					return "zehn"
				2:
					return "zwanzig"
				3:
					return "dreißig"
				4:
					return "vierzig"
				5:
					return "fünfzig"
				6:
					return "sechzig"
				7:
					return "siebzig"
				8:
					return "achtzig"
				9:
					return "neunzig"
				_: return ""
		5:
			match num:
				0:
					return ""
				1:
					return "ein"
				2:
					return "zwei"
				3:
					return "drei"
				4:
					return "vier"
				5:
					return "fünf"
				6:
					return "sechs"
				7:
					return "sieben"
				8:
					return "acht"
				9:
					return "neun"
				_: return ""
	return ""

func ziffer_verbal_suffix(pos: int) -> String:
	match pos:
		0: return ""
		1: return ""
		2: return "hundert"
		3: return ""
		4: return ""
		5: return "hundert"
		_: return ""
	

func int_to_verbal(num: int) -> String:
	
	if num == 0:
		return "null"
	
	var v_array = ["","","","","","",""]
	var word = ""
	
	for i in str(num).length():
		var ziffer = get_ziffer_at(num, i)
		var ziffer_v = ziffer_verbal(ziffer, i)
		if (i == 2 || i == 5) && ziffer_v:
			ziffer_v += ziffer_verbal_suffix(i)
		v_array[i] = ziffer_v
	
	var i = 0
	while i < str(num).length():
		var j = str(num).length() - i - 1
		# add the "tausend" infix between thousands and hundreds, if there are thousands (or tens of thousands, etc.)
		if j == 2 && (v_array[3] != "" || v_array[4] != "" || v_array[5] != ""):
			word += "tausend"
		if j != 4 && j != 1:
			word += v_array[j]
		else:
			if v_array[j - 1] != "" && v_array[j] != "":
				# everything but the 10s follow this pattern:
				if v_array[j] != "zehn":
					word += v_array[j - 1] + "und" + v_array[j]
				else:
					# everything in the 10s:
					match get_ziffer_at(num, j - 1):
						1:
							word += "elf"
						2:
							word += "zwölf"
						3:
							word += "dreizehn"
						4:
							word += "vierzehn"
						5:
							word += "fünfzehn"
						6:
							word += "sechzehn"
						7:
							word += "siebzehn"
						8:
							word += "achtzehn"
						9:
							word += "neunzehn"
				i += 1
			else:
				word += v_array[j]
		# final check: if we're done now and the final ziffer is 1 check whether there is a zehner; if not call it "eins", not "ein":
		if j == 0 && get_ziffer_at(num, 0) == 1 && get_ziffer_at(num, 1) == 0:
			word += "s"
		i += 1
	
	return word

func replace_at(string: String, pos: int, repl: String) -> String:
	return string.substr(0, pos) + repl + string.substr(pos+1, string.length() - 1 - pos)
