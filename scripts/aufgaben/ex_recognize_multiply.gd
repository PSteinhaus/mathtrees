extends Exercise

var factor1: int
var factor2: int
var solution: String

static var latest_factor1: int = -1
static var latest_factor2: int = -1

func _ready() -> void:
	super()
	new_challenge()

func level_color() -> Color:
	match level:
		0: return Color(1.,1.,1.)
		1: return Color(0.67, 0.658, 0.61, 1.0)
		_: return Color(0.44, 0.418, 0.352, 1.0)

func exType() -> ExType:
	return ExType.RECOGNIZE_MULTIPLY

func check_answer_internal() -> bool:
	var answer = %LabelAnswer.text
	return answer == solution

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
		if factor1 == latest_factor1 && factor2 == latest_factor2:
			continue
		# depending on the level reroll, if the challenge is too hard
		match level:
			0:
				# 1s 2s 10s
				if factor1 in [2,3,4]:
					accepted = true
			1:
				if factor1 in [1,2,3,4]:
					accepted = true
			2:
				if factor1 in [1,2,3,4,5,6]:
					accepted = true
			_:
				if factor1 in [1,2,3,4,5,6]:
					accepted = true
	latest_factor1 = factor1
	latest_factor2 = factor2
	var s = ""
	for i in factor1:
		if i > 0:
			s += " + "
		s += str(factor2)
	%LabelChallenge.text = s
	%LabelAnswer.text = ""
	solution = str(factor1) + " · " + str(factor2)

func _on_input_ziffern_number_pressed(number: int) -> void:
	var t: String = %LabelAnswer.text
	if t.length() < 6:
		%LabelAnswer.text += str(number)
	if t.contains(" · "):
		self.ready_to_check.emit(true)

func _on_input_ziffern_delete_pressed() -> void:
	var t = %LabelAnswer.text
	if t.is_empty():
		return
	if %LabelAnswer.text[-1] == " ":
		%LabelAnswer.text = %LabelAnswer.text.left(-3)
	else:
		%LabelAnswer.text = %LabelAnswer.text.left(-1)
	if not %LabelAnswer.text.contains(" · "):
		self.ready_to_check.emit(false)

func _on_input_ziffern_times_pressed() -> void:
	var t: String = %LabelAnswer.text
	if t.length() < 3:
		%LabelAnswer.text += " · "

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
		_: return INF
