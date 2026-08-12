extends RefCounted

const VIEW_DURATION := 0.18
const ITEM_DURATION := 0.16
const PRESS_DURATION := 0.07
const RELEASE_DURATION := 0.13


static func animate_entrance(
	owner: Node,
	control: Control,
	duration_scale: float = 1.0,
	delay: float = 0.0,
	start_scale: Vector2 = Vector2(0.985, 0.985)
) -> Tween:
	if owner == null or control == null or !is_instance_valid(control):
		return null
	_kill_control_tween(control)
	control.pivot_offset = control.size * 0.5
	if DisplayServer.get_name() == "headless":
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return null
	control.modulate.a = 0.0
	control.scale = start_scale
	if duration_scale <= 0.0:
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return null
	var tween := owner.create_tween().bind_node(control)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if delay > 0.0:
		tween.tween_interval(delay * duration_scale)
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, VIEW_DURATION * duration_scale)
	tween.tween_property(control, "scale", Vector2.ONE, VIEW_DURATION * duration_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	control.set_meta("_ui_motion_tween", tween)
	return tween


static func animate_item_entrance(
	owner: Node,
	control: Control,
	order: int,
	duration_scale: float = 1.0
) -> Tween:
	return animate_entrance(
		owner,
		control,
		duration_scale * ITEM_DURATION / VIEW_DURATION,
		float(maxi(order, 0)) * 0.035,
		Vector2(0.96, 0.96)
	)


static func bind_button(owner: Node, button: Button, duration_scale: float = 1.0) -> void:
	if owner == null or button == null or button.has_meta("_ui_motion_bound"):
		return
	button.set_meta("_ui_motion_bound", true)
	button.button_down.connect(func() -> void:
		_tween_scale(owner, button, Vector2(0.975, 0.975), PRESS_DURATION * duration_scale, Tween.EASE_OUT)
	)
	button.button_up.connect(func() -> void:
		_tween_scale(owner, button, Vector2.ONE, RELEASE_DURATION * duration_scale, Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func() -> void:
		if !button.button_pressed:
			_tween_scale(owner, button, Vector2.ONE, RELEASE_DURATION * duration_scale, Tween.EASE_OUT)
	)


static func _tween_scale(
	owner: Node,
	control: Control,
	target: Vector2,
	duration: float,
	ease: Tween.EaseType
) -> void:
	if !is_instance_valid(control):
		return
	_kill_control_tween(control)
	control.modulate.a = 1.0
	control.pivot_offset = control.size * 0.5
	if duration <= 0.0:
		control.scale = target
		return
	var tween := owner.create_tween().bind_node(control)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(control, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	control.set_meta("_ui_motion_tween", tween)


static func _kill_control_tween(control: Control) -> void:
	if !control.has_meta("_ui_motion_tween"):
		return
	var previous = control.get_meta("_ui_motion_tween")
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	control.remove_meta("_ui_motion_tween")
