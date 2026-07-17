extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")

var runtime: Node
var title_label: Label
var status_label: Label
var progress_label: Label
var complete_label: Label
var buttons := {}
var checks := {
	"need_resistor": false,
	"correct_polarity": false,
	"pa5_output": false
}
var completed := false
var mistakes := 0
var started_at := 0
var resetting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	runtime = DGBRuntime.new()
	runtime.setup({"game_id": "gpio-lab"})
	runtime.initialized.connect(_on_session_initialized)
	runtime.reset_requested.connect(_reset)
	runtime.pause_requested.connect(_on_pause_requested)
	runtime.resume_requested.connect(_on_resume_requested)
	add_child(runtime)
	started_at = Time.get_ticks_msec()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.text = "GPIO Wiring Lab"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.91, 1.0, 0.97))
	layout.add_child(title_label)

	var hint := Label.new()
	hint.text = "Toggle the three lab checks. The host receives progress and final score through postMessage."
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.70, 0.82, 0.86))
	layout.add_child(hint)

	var lab := HBoxContainer.new()
	lab.add_theme_constant_override("separation", 20)
	layout.add_child(lab)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(620, 360)
	lab.add_child(board)

	var board_box := VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 14)
	board.add_child(board_box)

	for row_text in [
		"STM32 PA5 ---- [resistor] ---- LED anode",
		"LED cathode ------------------- GND",
		"GPIO mode: output push-pull",
		"ODR bit: PA5 = 1"
	]:
		var row := Label.new()
		row.text = row_text
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", Color(0.12, 0.21, 0.26))
		board_box.add_child(row)

	var tools := VBoxContainer.new()
	tools.custom_minimum_size = Vector2(420, 360)
	tools.add_theme_constant_override("separation", 12)
	lab.add_child(tools)

	_add_toggle(tools, "need_resistor", "Place current-limiting resistor")
	_add_toggle(tools, "correct_polarity", "Connect LED polarity correctly")
	_add_toggle(tools, "pa5_output", "Set PA5 output high")

	var reset_button := Button.new()
	reset_button.text = "Reset attempt"
	reset_button.pressed.connect(_reset)
	tools.add_child(reset_button)

	progress_label = Label.new()
	progress_label.text = "Progress: 0/3"
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color(0.91, 1.0, 0.97))
	layout.add_child(progress_label)

	status_label = Label.new()
	status_label.text = "Waiting for host init."
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.86))
	layout.add_child(status_label)

	complete_label = Label.new()
	complete_label.text = ""
	complete_label.add_theme_font_size_override("font_size", 28)
	complete_label.add_theme_color_override("font_color", Color(0.52, 0.95, 0.72))
	layout.add_child(complete_label)

func _add_toggle(parent: Control, rule: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 52)
	button.toggled.connect(_on_toggle.bind(rule))
	parent.add_child(button)
	buttons[rule] = button

func _on_session_initialized(session: Dictionary) -> void:
	var level: Dictionary = session.get("level", {})
	var data: Dictionary = session.get("data", {})
	title_label.text = str(level.get("title", "GPIO Wiring Lab"))
	status_label.text = "Target: " + str(data.get("target", "complete lab checks"))
	runtime.log_info("Godot level initialized.")
	_evaluate()

func _on_toggle(pressed: bool, rule: String) -> void:
	if resetting:
		return
	if completed:
		return
	checks[rule] = pressed
	if !pressed:
		mistakes += 1
	_evaluate()

func _evaluate() -> void:
	var passed := 0
	for value in checks.values():
		if value:
			passed += 1
	var total := checks.size()
	var progress := float(passed) / float(total)
	progress_label.text = "Progress: %d/%d" % [passed, total]
	status_label.text = "Pass all checks to light the LED."
	if runtime:
		runtime.report_progress(progress, progress_label.text, {"passed": passed, "mistakes": mistakes})
	if passed == total and !completed:
		completed = true
		var elapsed := Time.get_ticks_msec() - started_at
		var score := maxi(60, 100 - mistakes * 8)
		complete_label.text = "LED is ON. Score: %d" % score
		runtime.complete(score, -1, elapsed, {"mistakes": mistakes, "passed": passed})

func _reset() -> void:
	resetting = true
	completed = false
	mistakes = 0
	started_at = Time.get_ticks_msec()
	complete_label.text = ""
	for rule in checks.keys():
		checks[rule] = false
		if buttons.has(rule):
			var button := buttons[rule] as Button
			button.set_pressed_no_signal(false)
	resetting = false
	_evaluate()

func _on_pause_requested() -> void:
	get_tree().paused = true

func _on_resume_requested() -> void:
	get_tree().paused = false
