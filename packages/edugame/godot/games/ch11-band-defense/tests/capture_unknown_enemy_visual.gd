extends SceneTree

const OUT_DIR := "C:/Users/sy/Desktop/dgbook-ref-main/dgbook-ref/.superpowers/visual-qa/enemies"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	get_root().size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene should load")
		quit(1)
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await _settle()

	game.select_level(1)
	await _settle()
	game.enemies.clear()
	for i in range(4):
		game._spawn_enemy(["config", "noise", "false_peak", "power_spike"][i])
		var enemy := game.enemies[i] as Dictionary
		enemy["diagnosed"] = false
		enemy["pos"] = Vector2(210 + i * 170, 260 + (i % 2) * 78)
		enemy["progress"] = 120.0 + i * 80.0
		enemy["symptomPhase"] = float(i) * 0.7
	game.queue_redraw()
	await _capture("unknown-fault-enemy-preview.png")
	game.queue_free()
	print("Unknown enemy visual capture written to: " + OUT_DIR)
	quit(0)


func _settle() -> void:
	for i in range(8):
		await process_frame


func _capture(filename: String) -> void:
	await _settle()
	var image := get_root().get_texture().get_image()
	image.save_png(OUT_DIR.path_join(filename))
