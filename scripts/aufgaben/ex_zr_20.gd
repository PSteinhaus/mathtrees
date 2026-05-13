extends Exercise

var num1: int
var num2: int
var is_plus: bool
var is_uebergang: bool
static var latest_num1: int = -1
static var latest_num2: int = -1

func _ready() -> void:
	super()
	# color the panels depending on how hard the level
	for p in [%Panel, %Panel2, %Panel3, %PanelVerbal]:
		p.self_modulate = level_color()
	new_challenge()

func level_color() -> Color:
	match level:
		0: return Color(1.,1.,1.)
		1: return Color(0.67, 0.658, 0.61, 1.0)
		_: return Color(0.44, 0.418, 0.352, 1.0)

func exType() -> ExType:
	return ExType.ZR_20

# TODO: implement
func check_answer_internal() -> bool:
	var answer = int(%LabelAnswer.text)
	return answer == num1 + num2 if is_plus else answer == num1 - num2

func new_challenge():
	$SubmitButton.animateHide()
	var accepted = false
	is_plus = randi_range(0,1) == 0
	is_uebergang = randi_range(0,1) == 0
	while !accepted:
		if is_plus:
			num1 = randi_range(1,19)
			num2 = randi_range(1,20 - num1)
		else:
			num1 = randi_range(1,20)
			num2 = randi_range(1, num1)
		if num1 == latest_num1 && num2 == latest_num2:
			continue
		if is_uebergang && !((is_plus && num1 < 10 && num1 + num2 >= 10) || (!is_plus && num1 >= 10 && num1 - num2 < 10)):
			continue
		accepted = true
	latest_num1 = num1
	latest_num2 = num2
	%LabelChallenge.text = str(num1) + " + " + str(num2) if is_plus else str(num1) + " − " + str(num2)
	%LabelVerbal.text = int_to_verbal(num1) + " plus " + int_to_verbal(num2) if is_plus else int_to_verbal(num1) + " minus " + int_to_verbal(num2)
	%LabelAnswer.text = ""

func _on_input_ziffern_number_pressed(number: int) -> void:
	var t: String = %LabelAnswer.text
	if t.length() < 3:
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
		0: return 140.
		_: return 170.
