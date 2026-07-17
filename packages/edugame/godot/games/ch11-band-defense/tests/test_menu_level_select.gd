extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_test_main_menu_is_initial_state(game)
	_test_level_select_prepares_selected_level(game)
	_test_attack_test_entry_is_removed(game)
	_test_recording_demo_plan_is_available_but_opt_in(game)
	game.queue_free()
	_finish()


func _test_main_menu_is_initial_state(game) -> void:
	_assert(str(game.state) == "main_menu", "game should open on the main menu")
	_assert(game.get("main_menu_panel") != null, "main menu panel should exist")
	if game.get("main_menu_panel") != null:
		_assert(bool(game.get("main_menu_panel").visible), "main menu should be visible at startup")
		_assert(bool(game.get("main_menu_panel").get_meta("map_style_background", false)), "main menu should use a map-style background treatment")
	_assert(game.get("side_panel") != null, "side HUD panel should exist")
	if game.get("side_panel") != null:
		_assert(!bool(game.get("side_panel").visible), "main menu should hide the right information HUD")
	_assert(game.has_method("show_level_select"), "game should expose level select entry")


func _test_level_select_prepares_selected_level(game) -> void:
	if !game.has_method("show_level_select"):
		_assert(false, "game should expose level select entry")
		return
	game.show_level_select()
	_assert(str(game.state) == "level_select", "level select should use its own menu state")
	_assert(game.get("level_select_panel") != null, "level select panel should exist")
	if game.get("level_select_panel") != null:
		_assert(bool(game.get("level_select_panel").visible), "level select should become visible")
	_assert(game.get("side_panel") != null, "side HUD panel should exist")
	if game.get("side_panel") != null:
		_assert(!bool(game.get("side_panel").visible), "level select should hide the right information HUD")
	_assert(game.has_method("select_level"), "game should expose select_level")
	if !game.has_method("select_level"):
		return
	game.select_level(3)
	_assert(str(game.state) == "intro", "selecting a level should prepare the level intro")
	if game.get("side_panel") != null:
		_assert(bool(game.get("side_panel").visible), "selected level intro should restore the right information HUD")
	_assert(int(game.current_level) == 3, "selecting level 3 should keep current_level at 3")
	_assert(int(game.current_wave) == 0, "selected level should start before wave 1")
	_assert(int(game.energy) >= 150, "selected later levels should have enough test energy")
	_assert(bool(game.unlocked.get("peak", false)), "selected later levels should unlock peak tower")
	_assert(bool(game.unlocked.get("power", false)), "selected later levels should unlock power tower")
	game.start_game()
	_assert(str(game.state) == "wave_running", "selected level should start a wave")
	_assert(int(game.current_level) == 3, "start_game should not reset a selected level back to 1")
	_assert(int(game.current_wave) == 1, "selected level should start at wave 1")


func _test_attack_test_entry_is_removed(game) -> void:
	_assert(!game.has_method("start_attack_test"), "attack test entry should be removed from the public menu flow")


func _test_recording_demo_plan_is_available_but_opt_in(game) -> void:
	_assert(game.has_method("_recording_demo_build_plan"), "recording demo should expose a deterministic build plan")
	if game.has_method("_recording_demo_build_plan"):
		var plan := game._recording_demo_build_plan() as Dictionary
		_assert(plan.has("1-1"), "recording demo should cover level 1 wave 1")
		_assert(plan.has("3-3"), "recording demo should cover final wave")
	_assert(game.has_method("_recording_demo_safety_budget"), "recording demo should expose a safety budget for reliable walkthrough capture")
	if game.has_method("_recording_demo_safety_budget"):
		var budget := game._recording_demo_safety_budget() as Dictionary
		_assert(int(budget.get("energy", 0)) >= 900, "recording demo should have enough energy to show builds and upgrades")
		_assert(int(budget.get("towerLevel", 0)) >= 3, "recording demo should raise showcased towers to their distinctive level")
		for tower_id in ["i2c", "filter", "peak", "power"]:
			_assert((budget.get("unlocked", []) as Array).has(tower_id), "recording demo should unlock tower: %s" % tower_id)
	_assert(!bool(game.recording_demo_started), "recording demo should not start without the URL opt-in")


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("menu level select tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
