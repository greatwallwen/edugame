extends SceneTree

const OUT_DIR := "C:/Users/sy/Desktop/dgbook-ref-main/dgbook-ref/.superpowers/visual-qa/hud"


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

	game.show_main_menu()
	await _capture("01-main-menu.png")

	game.show_level_select()
	await _capture("02-level-select.png")

	game.select_level(1)
	await _settle()
	await _capture("03-game-hud.png")

	game._open_slot_menu(0)
	await _settle()
	await _capture("04-slot-menu.png")
	game._close_slot_menu()

	game._show_quiz()
	await _settle()
	await _capture("05-quiz-dialog.png")
	game.quiz_panel.visible = false

	game.enemies.clear()
	game._spawn_enemy("config")
	var diagnostic_enemy := game.enemies[0] as Dictionary
	diagnostic_enemy["pos"] = Vector2(360, 260)
	game._open_diagnostic_menu(diagnostic_enemy)
	await _settle()
	await _capture("08-diagnostic-menu.png")
	game._choose_diagnostic_method("read_registers")
	await _settle()
	await _capture("10-diagnostic-data-overlay.png")
	game._close_diagnostic_menu()

	game._show_codex_popup()
	await _settle()
	await _capture("09-codex-popup.png")
	game._hide_codex_popup()

	game.select_level(2)
	await _settle()
	await _capture("06-level2-game-hud.png")

	game.select_level(3)
	await _settle()
	await _capture("07-level3-game-hud.png")

	game.queue_free()
	print("HUD visual captures written to: " + OUT_DIR)
	quit(0)


func _settle() -> void:
	await create_timer(0.28).timeout
	for i in range(3):
		await process_frame


func _capture(filename: String) -> void:
	await _settle()
	var image := get_root().get_texture().get_image()
	image.save_png(OUT_DIR.path_join(filename))
