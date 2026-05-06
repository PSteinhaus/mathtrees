extends Exercise

var factor1: int
var factor2: int
var co_factor1: int
var co_factor2: int

static var latest_factor1: int = -1
static var latest_factor2: int = -1

func _ready() -> void:
	super()
	# color the panels depending on how hard the level
	for p in [%Panel, %Panel2, %Panel3, %PanelVerbal]:
		p.self_modulate = level_color()
	new_challenge()
	self.progress_erosion_per_sec = 1.8

func level_color() -> Color:
	match level:
		0: return Color(1.,1.,1.)
		1: return Color(0.67, 0.658, 0.61, 1.0)
		_: return Color(0.44, 0.418, 0.352, 1.0)

func exType() -> ExType:
	return ExType.MULTIPLY_STELLEN

# TODO: implement
func check_answer_internal() -> bool:
	var answer = int(%LabelAnswer.text)
	return answer == factor1 * co_factor1 * factor2 * co_factor2

func int_to_verbal(num: int) -> String:
	match num:
		0:
			return "null"
		1:
			return "eins"
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
		10:
			return "zehn"
	return ""

func new_challenge():
	$SubmitButton.animateHide()
	var accepted = false
	while !accepted:
		factor1 = randi_range(1,10)
		factor2 = randi_range(1,10)
		co_factor1 = 10 ** randi_range(0,3)
		co_factor2 = 10 ** randi_range(0,3)
		if factor1 == latest_factor1 && factor2 == latest_factor2:
			continue
		if co_factor1 == 1 && co_factor2 == 1: # we want larger things
			continue
		# depending on the level reroll, if the challenge is too hard
		match level:
			0:
				# 1s 2s 10s
				if (factor1 in [1,2,10] || factor2 in [1,2,10]) && (co_factor1 in [1,10] && co_factor2 in [1,10]):
					accepted = true
			1:
				# 2s 5s
				if (factor1 in [2,5] || factor2 in [2,5]) && (co_factor1 in [1,10] && co_factor2 in [10,100]):
					accepted = true
			2:
				# 3s, no 1s no 10s
				if (factor1 in [2,5] || factor2 in [2,5]) && (co_factor1 in [1,10] && co_factor2 in [10,100,1000]):
					accepted = true
			3:
				# 4s, no 1s no 10s
				if (factor1 in [2,5] || factor2 in [2,5]) && (co_factor1 in [10,100] && co_factor2 in [10,100,1000]):
					accepted = true
			4:
				# 6s, no 1s no 10s
				if (factor1 in [2,5] || factor2 in [2,5]) && (co_factor1 in [10,100,1000] && co_factor2 in [10,100]):
					accepted = true
			_:
				accepted = true
	latest_factor1 = factor1 * co_factor1
	latest_factor2 = factor2 * co_factor2
	%LabelChallenge.text = str(latest_factor1) + " · " + str(latest_factor2)
	#%LabelVerbal.text = int_to_verbal(factor1) + " mal " + int_to_verbal(factor2)
	%LabelVerbal.text = "" # FIXME: maybe add this later?
	%LabelAnswer.text = ""

func _on_input_ziffern_number_pressed(number: int) -> void:
	var t: String = %LabelAnswer.text
	if t.length() < 9:
		%LabelAnswer.text += str(number)
	self.ready_to_check.emit(true)

func _on_input_ziffern_delete_pressed() -> void:
	%LabelAnswer.text = %LabelAnswer.text.left(-1)
	if %LabelAnswer.text.is_empty():
		self.ready_to_check.emit(false)

func _on_submit_button_pressed() -> void:
	# check whether the answer is correct
	check_answer()

func _on_ready_to_check(val: bool) -> void:
	show_submit_button(val)

func show_submit_button(val: bool) -> void:
	if val:
		$SubmitButton.animateShow()
	else:
		$SubmitButton.animateHide()

func get_progress_bar() -> ProgressBar:
	return %BGProgressBar

func set_input_enabled(val: bool):
	%InputZiffern.set_input_enabled(val)
	if !val:
		show_submit_button(false)

func progress_for_level_up() -> float:
	match level:
		0: return 150.
		1: return 180.
		2: return 220.
		3: return 240.
		4: return 250.
		5: return INF
		6: return INF
		7: return INF
		8: return INF
		_: return INF
