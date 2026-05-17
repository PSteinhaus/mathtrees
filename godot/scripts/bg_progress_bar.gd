extends ProgressBar

var tween:
	set(val):
		if tween:
			tween.kill()
		tween = val

func animate_progress(target_value: float, duration: float = 1.0):
	tween = create_tween()
	tween.tween_property(self, "value", target_value, duration).set_trans(Tween.TransitionType.TRANS_CUBIC)
