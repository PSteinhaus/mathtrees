extends Button

enum State {
	SHOWN,
	SHOWING,
	HIDING,
	HIDDEN
}
var state: State = State.HIDDEN
var initial_pos
var active_tween:
	set(val):
		if active_tween:
			active_tween.kill()
		active_tween = val

func _ready() -> void:
	initial_pos = position
	print("initial_pos: "+str(initial_pos))

func animateShow():
	if state != State.SHOWING && state != State.SHOWN:
		state = State.SHOWING
		visible = true
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
		var end_pos = initial_pos + Vector2(0, -size.y)
		tween.tween_property(self, "position", end_pos, 0.9)
		tween.parallel().tween_callback(func():
			disabled = false
		).set_delay(0.5)
		tween.tween_callback(func():
			state = State.SHOWN
		)
		active_tween = tween

func animateHide():
	if state == State.SHOWN || state == State.SHOWING:
		state = State.HIDING
		disabled = true
		var tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "position", initial_pos, 0.7)
		tween.tween_callback(func():
			visible = false
			state = State.HIDDEN
		)
		active_tween = tween
