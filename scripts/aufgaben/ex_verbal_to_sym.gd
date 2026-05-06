extends Exercise

var solution: int

func _ready() -> void:
	super()
	# color the panels depending on how hard the level
	for p in [%Panel3, %PanelVerbal]:
		p.self_modulate = level_color()
	self.progress_erosion_per_sec = 1.5
	new_challenge()

func level_color() -> Color:
	match level:
		0: return Color(1.,1.,1.)
		1: return Color(0.73, 0.812, 0.82, 1.0)
		_: return Color(0.6, 0.674, 0.69, 1.0)

func exType() -> ExType:
	return ExType.VERBAL_TO_SYMBOLIC

func check_answer_internal() -> bool:
	var answer = int(%LabelAnswer.text)
	return answer == solution

func new_challenge():
	$SubmitButton.animateHide()

	match level:
		0: solution = randi_range(1,99)
		1: solution = randi_range(1,999)
		2: 
			var n_str = str(randi_range(1,9999))
			if randi() % 2 == 0 && int(n_str) > 1000:
				# Construct a new string with the second character replaced
				n_str = replace_at(n_str, 1, "0")
			solution = int(n_str)
		3: 
			var n_str = str(randi_range(1,99999))
			if randi() % 6 == 0 && int(n_str) > 10000:
				n_str = replace_at(n_str, 2, "0")
			elif randi() % 6 == 0 && int(n_str) > 10000:
				n_str = replace_at(n_str, 1, "0")
				n_str = replace_at(n_str, 2, "0")
			elif randi() % 6 == 0 && int(n_str) > 1000 && int(n_str) < 10000:
				n_str = replace_at(n_str, 1, "0")
			solution = int(n_str)
		_:
			var n_str = str(randi_range(1,999999))
			if randi() % 8 == 0 && int(n_str) > 100000:
				n_str = replace_at(n_str, 3, "0")
			elif randi() % 7 == 0 && int(n_str) > 100000:
				n_str = replace_at(n_str, 2, "0")
				n_str = replace_at(n_str, 3, "0")
			elif randi() % 7 == 0 && int(n_str) > 100000:
				n_str = replace_at(n_str, 3, "0")
				n_str = replace_at(n_str, 4, "0")
			elif randi() % 4 == 0 && int(n_str) > 10000 && int(n_str) < 100000:
				n_str = replace_at(n_str, 2, "0")
			elif randi() % 4 == 0 && int(n_str) > 1000 && int(n_str) < 10000:
				n_str = replace_at(n_str, 1, "0")
			solution = int(n_str)
	
	# depending on the level reroll, if the challenge is too hard
	print(solution)
	print(int_to_verbal(solution))
	%LabelVerbal.text = int_to_verbal(solution)
	%LabelAnswer.text = ""

func _on_input_ziffern_number_pressed(number: int) -> void:
	var t: String = %LabelAnswer.text
	if t.length() < 6:
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
		0: return 70.
		1: return 160.
		2: return 230.
		3: return 260.
		_: return INF
