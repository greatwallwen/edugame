extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "template main scene should load")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var runtime = game.get("runtime")
	_assert(runtime != null, "template should expose DGBRuntime")
	if runtime != null:
		runtime.bridge.receive_payload({
			"type": "DGB_GODOT_INIT",
			"version": 1,
			"level": {"title": "Injected Lab"},
			"data": {"gameId": "gpio-lab", "target": "verify runtime"}
		})
		_assert(game.title_label.text == "Injected Lab", "template should consume normalized session level")
		_assert(runtime.current_session().data.target == "verify runtime", "template runtime should preserve host data")
	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("template runtime integration tests passed")
		quit(0)
