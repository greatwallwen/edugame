extends SceneTree

const REQUIRED_STATIC_IDS := [
	"boss_phase_1", "boss_phase_2", "boss_phase_3",
	"sensor_checkpoint", "trust_checkpoint", "component",
	"shop", "service", "ordinary_reward", "elite_reward"
]
const COVERAGE_TAGS := [
	"smoke", "light", "i2c", "filter",
	"display", "uart", "alarm", "scheduler"
]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var lab_script := load("res://dev/node_lab.gd")
	_assert(lab_script != null, "node lab script should exist")
	if lab_script == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var lab = lab_script.new()
	game.add_child(lab)
	lab.configure(game)
	await process_frame
	var entries: Array = lab.catalog_entries()
	var lab_root = game.find_child("NodeLabRoot", true, false)
	var catalog = game.find_child("NodeLabCatalog", true, false)
	var run_hud = game.find_child("RunHud", true, false)
	var return_button = game.find_child("NodeLabReturn", true, false)
	var restart_button = game.find_child("NodeLabRestart", true, false)
	var arena = game.find_child("EncounterArena", true, false)
	var hand_dock = game.find_child("HandDock", true, false)
	_assert(lab_root != null and lab_root.theme == game.ui_theme, "lab root should use the game UI theme")
	_assert(catalog != null and catalog.visible and !game.shell.visible, "catalog should hide the normal shell")
	_assert(run_hud != null and run_hud.visible and game.shell.offset_top == 0.0, "catalog should restore the normal header position")

	for enemy_id in game.enemy_defs.keys():
		_assert(_has_entry(entries, str(enemy_id)), "lab should include enemy %s" % enemy_id)
	for event_id in game.event_defs.keys():
		_assert(_has_entry(entries, str(event_id)), "lab should include event %s" % event_id)
	for required_id in REQUIRED_STATIC_IDS:
		_assert(_has_entry(entries, required_id), "lab should include %s" % required_id)

	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		_assert(bool(game.start_lab_scenario(entry, "starter")), "lab should launch %s" % entry.get("id", "scenario"))
		_assert(game.stability == game.max_stability, "lab fixture should restore full stability")
		_assert(game.budget == 100, "lab fixture should provide deterministic budget")
		_assert(game.relics.is_empty(), "lab fixture should clear components")
		_assert(_entry_reached_expected_state(game, entry), "%s should reach its expected state" % entry.get("id", "scenario"))

	var coverage_entry := _entry(entries, "mq2_warmup")
	_assert(bool(game.start_lab_scenario(coverage_entry, "coverage")), "coverage fixture should launch")
	await process_frame
	for tag in COVERAGE_TAGS:
		_assert(game._deck_has_any_tag([tag]), "coverage fixture should contain tag %s" % tag)
	_assert(catalog != null and !catalog.visible, "scenario should hide the catalog")
	_assert(return_button != null and return_button.visible and restart_button != null and restart_button.visible, "scenario should expose the lab toolbar controls")
	_assert(run_hud != null and !run_hud.visible and game.shell.visible and game.shell.offset_top == 58.0, "scenario toolbar should replace RunHud")
	_assert(arena != null and arena.is_visible_in_tree() and hand_dock != null and hand_dock.is_visible_in_tree(), "lab combat should expose the redesigned arena and hand dock")

	game.stability = 3
	game.budget = 2
	game.relics = ["pullup_4k7"]
	var runtime_calls: Array = []
	game.runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: runtime_calls.append(payload))
	_assert(bool(game.restart_lab_scenario()), "restart should relaunch the current scenario")
	await process_frame
	_assert(game.stability == game.max_stability and game.budget == 100, "restart should restore fixture resources")
	_assert(game.relics.is_empty(), "restart should clear scenario components")
	_assert(runtime_calls.is_empty(), "restart should keep runtime calls at zero")
	game.return_to_node_lab()
	await process_frame
	_assert(game.state == game.RunState.WAITING, "return should leave scenario gameplay")
	_assert(catalog != null and catalog.visible and !game.shell.visible, "return should restore the catalog")
	_assert(run_hud != null and run_hud.visible and game.shell.offset_top == 0.0, "return should restore the normal header position")

	if !game.has_method("_enter_node_lab"):
		_assert(false, "game should expose the hidden node lab launcher")
	else:
		game._enter_node_lab()
		await process_frame
		_assert(game.node_lab_active, "manual lab entry should activate lab mode")
		_assert(game.find_child("NodeLabCatalog", true, false) != null, "lab should render a catalog")
		_assert(game.find_child("NodeLabRestart", true, false) != null, "lab should expose restart")
		_assert(game.find_child("NodeLabReturn", true, false) != null, "lab should expose return")

	game.queue_free()
	await process_frame
	_finish()


func _entry_reached_expected_state(game, entry: Dictionary) -> bool:
	match str(entry.get("kind", "")):
		"enemy", "boss_phase", "checkpoint_sensor", "checkpoint_trust":
			return game.state == game.RunState.COMBAT
		"event":
			return game.state == game.RunState.EVENT
		"component":
			return game.state == game.RunState.COMPONENT
		"shop":
			return game.state == game.RunState.SHOP
		"service":
			return game.state == game.RunState.REST
		"reward":
			return game.state == game.RunState.REWARD
	return false


func _entry(entries: Array, expected_id: String) -> Dictionary:
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == expected_id:
			return entry
	return {}


func _has_entry(entries: Array, expected_id: String) -> bool:
	return !_entry(entries, expected_id).is_empty()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 node lab tests passed")
		quit(0)
