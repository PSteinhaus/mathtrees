extends Exercise

var stelle: int
var ziffer: int
var wert: int
var einheit: String
var einheit_klein: String
var faktor: int
var einheiten = ["€", "km", "m", "kg"]
var einheiten_klein = ["ct", "m", "cm", "g"]
var faktoren := [100, 1000, 100, 1000]
var solution: int
var answer
var phase: Phase = Phase.STELLE

enum Phase {
	STELLE,
	WERT,
	LOESUNG
}

func _ready() -> void:
	super()
	#progress_erosion_per_sec = 1.5
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
	return ExType.COMMA

func advance_phase() -> void:
	var next_phase: Phase
	match phase:
		Phase.STELLE: next_phase = Phase.WERT
		Phase.WERT: next_phase = Phase.LOESUNG
		Phase.LOESUNG: next_phase = Phase.STELLE
	phase = next_phase

# TODO: implement
func check_answer_internal() -> bool:
	var correct: bool = answer == solution
	if correct:
		advance_phase()
	return correct

func get_ziffer_at(num: int, pos: int) -> int:
	var teiler = 10 ** pos
	@warning_ignore("integer_division")
	return (num / teiler) % 10

func new_challenge():
	$SubmitButton.animateHide()
	match phase:
		Phase.STELLE:
			var i = randi() % einheiten.size()
			einheit = einheiten[i]
			einheit_klein = einheiten_klein[i]
			faktor = faktoren[i]
			stelle = randi_range(0, str(faktor).length() - 1)
			print("Stelle: "+str(stelle))
			ziffer = randi_range(1,9)
			print("Ziffer: "+str(ziffer))
			var s: String = ""
			for j in (stelle + 1):
				if j == 1:
					s += ","
				s += "0" if stelle != j else str(ziffer)
			%LabelChallengeStelle.text = s + " " + einheit
			solution = stelle
		
			%VBoxContainerStelle.visible = true
			%VBoxContainerWert.visible = false
			%VBoxContainerLoesung.visible = false
		Phase.WERT:
			%VBoxContainerStelle.visible = false
			%VBoxContainerWert.visible = true
			%VBoxContainerLoesung.visible = false
			var l = %LabelVerbalWert
			l.text = "Wie viel ist ein "
			match stelle:
				0: l.text += ""
				1: l.text += "zehntel "
				2: l.text += "hundertstel "
				3: l.text += "tausendstel "
			l.text += einheit + "?"
			
			l = %LabelFaktor
			match stelle:
				0: l.text = "1"
				1: l.text = "10"
				2: l.text = "100"
				3: l.text = "1000"
			
			%LabelAnswerFaktor.text = " " + einheit_klein
			%LabelUnit.text = "1 " + einheit
			
			@warning_ignore("integer_division")
			solution = faktor / int(%LabelFaktor.text)
		Phase.LOESUNG:
			%VBoxContainerStelle.visible = false
			%VBoxContainerWert.visible = false
			%VBoxContainerLoesung.visible = true
			
			%LabelAnswerLoesung.text = " " + einheit_klein
			%LabelChallengeLoesung.text = %LabelChallengeStelle.text
			%LabelVerbalLoesung.text = "Du hast " + str(ziffer) + " davon, also..."
			@warning_ignore("integer_division")
			solution = ziffer * (faktor / int(%LabelFaktor.text))

func active_loesung_label() -> Label:
	match phase:
		Phase.WERT:
			return %LabelAnswerFaktor
		Phase.LOESUNG:
			return %LabelAnswerLoesung
		_:
			return null

func _on_input_ziffern_number_pressed(number: int) -> void:
	match phase:
		Phase.WERT, Phase.LOESUNG:
			var l = active_loesung_label()
			var parts = l.text.split(" ")
			if parts[0].length() < 4:
				parts[0] += str(number)
			l.text = parts[0] + " " + parts[1]
			answer = int(parts[0])
			self.ready_to_check.emit(true)

func _on_input_ziffern_delete_pressed() -> void:
	match phase:
		Phase.WERT, Phase.LOESUNG:
			var l = active_loesung_label()
			# split the einheit
			var parts = l.text.split(" ")
			parts[0] = parts[0].left(-1)
			if parts[0].is_empty():
				self.ready_to_check.emit(false)
			l.text = parts[0] + " " + parts[1]
			answer = int(parts[0])

func _on_submit_button_pressed() -> void:
	# check whether the answer is correct
	check_answer()

func _on_ready_to_check(val: bool) -> void:
	if phase != Phase.STELLE:
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
		3: return INF
		_: return INF

func _on_button_einer_pressed() -> void:
	answer = 0
	check_answer()

func _on_button_zehntel_pressed() -> void:
	answer = 1
	check_answer()
	
func _on_button_hundertstel_pressed() -> void:
	answer = 2
	check_answer()

func _on_button_tausendstel_pressed() -> void:
	answer = 3
	check_answer()
