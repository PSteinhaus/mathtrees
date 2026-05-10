extends Exercise

var first_number: int
var second_number: int
var to_uebergang: int
var from_uebergang: int
var uebergang: bool
var plus: bool
var solution: int
var answer
var phase: Phase = Phase.JA_NEIN

enum Phase {
	JA_NEIN,
	UEBER,
	LOESUNG
}

func _ready() -> void:
	super()
	progress_erosion_per_sec = 1.5
	# color the panels depending on how hard the level
	#for p in [%Panel, %Panel2, %Panel3, %PanelVerbal]:
	#	p.self_modulate = level_color()
	new_challenge()

func level_color() -> Color:
	match level:
		0: return Color(1.,1.,1.)
		1: return Color(0.67, 0.658, 0.61, 1.0)
		_: return Color(0.44, 0.418, 0.352, 1.0)

func exType() -> ExType:
	return ExType.OVER_TEN

func advance_phase() -> void:
	var next_phase: Phase
	match phase:
		Phase.JA_NEIN:
			if uebergang:
				next_phase = Phase.UEBER
			else:
				next_phase = Phase.JA_NEIN
		Phase.UEBER: next_phase = Phase.LOESUNG
		Phase.LOESUNG: next_phase = Phase.JA_NEIN
	phase = next_phase

# TODO: implement
func check_answer_internal() -> bool:
	var correct: bool
	match phase:
		Phase.JA_NEIN:
			correct = answer == uebergang
		_:
			correct = answer == solution
	if correct:
		advance_phase()
	return correct

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

func get_ziffer_at(num: int, pos: int) -> int:
	var teiler: int = 10 ** pos
	@warning_ignore("integer_division")
	return (num / teiler) % 10

func new_challenge():
	$SubmitButton.animateHide()
	%VBoxContainerJaNein.hide()
	%VBoxContainerUeber.hide()
	%VBoxContainerLoesung.hide()
	match phase:
		Phase.JA_NEIN:
			first_number = 0
			second_number = 0
			plus = (randi() % 2) == 0
			uebergang = (randi() % 2) == 0	
			if plus:
				if uebergang:
					while get_ziffer_at(first_number, 1) == get_ziffer_at(first_number + second_number, 1):
						first_number = randi_range(1, 89)
						second_number = randi_range(2, 9)
				else:
					first_number = 9
					second_number = 9
					while (get_ziffer_at(first_number, 0) + get_ziffer_at(second_number, 0) >= 10) || (first_number + second_number >= 100):
						first_number = randi_range(1, 98)
						second_number = randi_range(1, 9)
			else:
				if uebergang:
					while get_ziffer_at(first_number, 1) == get_ziffer_at(first_number - second_number, 1):
						first_number = randi_range(11, 98)
						second_number = randi_range(2, 9)
				else:
					first_number = 9
					second_number = 9
					while (get_ziffer_at(first_number, 0) - get_ziffer_at(second_number, 0) < 0) || (first_number - second_number <= 0):
						first_number = randi_range(1, 98)
						second_number = randi_range(1, 9)
			%VBoxContainerJaNein.visible = true
			%LabelChallengeJaNein.text = str(first_number) + " + " + str(second_number) if plus else str(first_number) + " − " + str(second_number)
		Phase.UEBER:
			%VBoxContainerUeber.visible = true
			%LabelChallengeUeber.text = str(first_number) + " + " + str(second_number) if plus else str(first_number) + " − " + str(second_number)
			%LabelAnswer.text = ""
			solution = (get_ziffer_at(first_number + second_number, 1) if plus else get_ziffer_at(first_number, 1)) * 10
		Phase.LOESUNG:
			%VBoxContainerLoesung.visible = true
			%LabelAnswerLoesung.text = ""
			%LabelToUebergang.text = ""
			%LabelFromUebergang.text = ""
			%LabelChallengeLoesung.text = str(first_number) + " + " + str(second_number) if plus else str(first_number) + " − " + str(second_number)
			to_uebergang = 10 - get_ziffer_at(first_number, 0) if plus else get_ziffer_at(first_number, 0)
			from_uebergang = second_number - to_uebergang
			solution = first_number + second_number if plus else first_number - second_number
	#%LabelChallenge.text = str(factor1) + " · " + str(factor2)
	#%LabelVerbal.text = int_to_verbal(factor1) + " mal " + int_to_verbal(factor2)
	#%LabelAnswer.text = ""

func active_loesung_label() -> Label:
	match phase:
		Phase.UEBER:
			return %LabelAnswer
		Phase.LOESUNG:
			if %LabelToUebergang.text == "":
				return %LabelToUebergang
			elif %LabelFromUebergang.text == "":
				return %LabelFromUebergang
			else:
				return %LabelAnswerLoesung
		_:
			return null

func _on_input_ziffern_number_pressed(number: int) -> void:
	match phase:
		Phase.UEBER:
			var t: String = %LabelAnswer.text
			if t.length() < 3:
				%LabelAnswer.text += str(number)
			answer = int(%LabelAnswer.text)
			self.ready_to_check.emit(true)
		Phase.LOESUNG:
			var l = active_loesung_label()
			var t: String = l.text
			var is_loesung = l == %LabelAnswerLoesung
			if t == "" || (is_loesung && t.length() < 3):
				l.text += str(number)
			if is_loesung:
				answer = int(l.text)
				self.ready_to_check.emit(true)

func _on_input_ziffern_delete_pressed() -> void:
	match phase:
		Phase.UEBER:		
			%LabelAnswer.text = %LabelAnswer.text.left(-1)
			if %LabelAnswer.text.is_empty():
				self.ready_to_check.emit(false)
		Phase.LOESUNG:
			# for now: just clear everything
			%LabelToUebergang.text = ""
			%LabelFromUebergang.text = ""
			%LabelAnswerLoesung.text = ""
			self.ready_to_check.emit(false)

func _on_submit_button_pressed() -> void:
	# check whether the answer is correct
	check_answer()

func _on_ready_to_check(val: bool) -> void:
	if phase != Phase.JA_NEIN:
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
	%InputZiffernLoesung.set_input_enabled(val)
	if val == false:
		show_submit_button(val)

func progress_for_level_up() -> float:
	match level:
		0: return 140.
		1: return 170.
		2: return 230.
		3: return 260.
		4: return 290.
		_: return INF

func _on_button_yes_pressed() -> void:
	answer = true
	check_answer()

func _on_button_no_pressed() -> void:
	answer = false
	check_answer()
