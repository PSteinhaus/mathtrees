extends Control

# Define the two custom signals
signal number_pressed(number: int)
signal delete_pressed()
signal times_pressed()

# Called when the node is added to the scene
func _ready():
	for i in range(0, 10):
		var button_name = "Button%d" % i
		var button = get_node("%"+button_name)
		button.connect("pressed", Callable(self, "_on_button_pressed").bind(i))
	%ButtonDelete.connect("pressed", Callable(self, "_on_button_pressed").bind(-1))
	%ButtonTimes.connect("pressed", Callable(self, "_on_button_pressed").bind(-2))

# Handle button press events
func _on_button_pressed(i):
	if i == -1:
		emit_signal("delete_pressed")
	elif i == -2:
		emit_signal("times_pressed")
	else:
		emit_signal("number_pressed", i)

func set_input_enabled(val: bool):
	for i in range(0, 10):
		var button_name = "Button%d" % i
		var button = get_node("%"+button_name)
		button.disabled = !val
	%ButtonDelete.disabled = !val
	%ButtonTimes.disabled = !val
