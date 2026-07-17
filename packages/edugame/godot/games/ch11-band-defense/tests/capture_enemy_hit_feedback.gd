extends SceneTree

const OUT_PATH := "res://visual-audit/enemy-hit-feedback.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene should load")
		quit(1)
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.select_level(1)
	game.state = "wave_running"
	game.enemies.clear()
	game.attack_effects.clear()
	game._clear_enemy_hit_feedback()

	var setups := [
		{"type": "config", "tower": "i2c", "pos": Vector2(205, 212), "from": Vector2(132, 300), "ratio": 0.82, "matched": true},
		{"type": "noise", "tower": "filter", "pos": Vector2(380, 350), "from": Vector2(315, 260), "ratio": 0.52, "matched": true},
		{"type": "false_peak", "tower": "peak", "pos": Vector2(565, 210), "from": Vector2(510, 320), "ratio": 0.20, "matched": true},
		{"type": "power_spike", "tower": "power", "pos": Vector2(745, 355), "from": Vector2(690, 260), "ratio": 0.68, "matched": true},
		{"type": "noise", "tower": "i2c", "pos": Vector2(855, 205), "from": Vector2(785, 295), "ratio": 0.72, "matched": false},
	]
	for index in range(setups.size()):
		var setup := setups[index] as Dictionary
		game._spawn_enemy(str(setup.type))
		var enemy := game.enemies[-1] as Dictionary
		enemy["pos"] = setup.pos
		enemy["progress"] = 100.0 + float(index) * 22.0
		enemy["diagnosed"] = true
		enemy["hp"] = float(enemy.maxHp) * float(setup.ratio)
		enemy["hitReactionTtl"] = 0.19
		enemy["hitReactionDuration"] = 0.26
		enemy["hitDirection"] = ((setup.pos as Vector2) - (setup.from as Vector2)).normalized()
		enemy["lastMatched"] = bool(setup.matched)
		game._add_enemy_hit_effect(enemy, str(setup.tower), bool(setup.matched), 24.0, enemy.hitDirection)
		(game.hit_effects[-1] as Dictionary)["ttl"] = 0.19
		game._add_attack_effect(setup.from, setup.pos, str(setup.tower), bool(setup.matched), str((game.tower_defs[str(setup.tower)] as Dictionary).get("attackStyle", "")))
		(game.attack_effects[-1] as Dictionary)["ttl"] = 0.22

	game._spawn_enemy("config")
	var dying := game.enemies[-1] as Dictionary
	dying["pos"] = Vector2(530, 500)
	dying["progress"] = 240.0
	dying["diagnosed"] = true
	dying["hp"] = 0.0
	game._add_death_echo(dying)
	(game.death_echoes[-1] as Dictionary)["ttl"] = 0.13
	game.enemies.pop_back()

	game.hovered_enemy = game.enemies[2]
	game.hover_health_active = true
	game.hover_health_alpha = 1.0
	game.hover_pointer_known = false
	game.set_process(false)
	game.queue_redraw()
	for index in range(4):
		await process_frame
	var image := get_root().get_texture().get_image()
	if image == null:
		game.queue_free()
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	game.queue_free()
	if error != OK:
		push_error("failed to save enemy hit feedback capture")
		quit(1)
		return
	print("enemy hit feedback capture written to: " + absolute_path)
	quit(0)
