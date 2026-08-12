extends SceneTree

const SAVE_PATH := "user://ch09_run_flow_test.json"
const SETTINGS_PATH := "user://ch09_settings_flow_test.cfg"
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var game = load("res://scenes/main.tscn").instantiate()
	game.run_save_path = SAVE_PATH
	game.settings_path = SETTINGS_PATH
	get_root().add_child(game)
	await process_frame
	game._reset_run()
	game.formal_run_active = true
	game.current_layer = 3
	game.pending_service_energy_penalty = -1
	game.pending_service_reroute_lock = true
	_assert(game._save_run_now(), "map state should save")
	game.current_layer = 0
	game.pending_service_energy_penalty = 0
	game.pending_service_reroute_lock = false
	_assert(game._resume_formal_run(), "map state should resume")
	_assert(game.state == game.RunState.MAP and game.current_layer == 3 and game.pending_service_energy_penalty == -1 and game.pending_service_reroute_lock, "map state and queued service costs should round-trip")

	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game.stability = 43
	game.repair_progress = 7
	game._save_run_now()
	game.stability = 1
	game.repair_progress = 0
	_assert(game._resume_formal_run(), "combat state should resume")
	_assert(game.state == game.RunState.COMBAT and game.stability == 43 and game.repair_progress == 7, "combat resources should round-trip")

	game._open_reward()
	_assert(game._save_run_now(), "reward state should save")
	game.reward_choices.clear()
	_assert(game._resume_formal_run() and game.state == game.RunState.REWARD and game.reward_choices.size() == 3, "reward choices should round-trip")

	var event_id := str(game.event_defs.keys()[0])
	game._begin_question_event(game.event_defs[event_id])
	_assert(game._save_run_now(), "event state should save")
	game.current_event.clear()
	_assert(game._resume_formal_run() and game.state == game.RunState.EVENT and !game.current_event.is_empty(), "event state should round-trip")

	game.state = game.RunState.REST; game.current_node = {"type": "service", "label": "test"}; _assert(game._save_run_now(), "rest state should save")
	game.state = game.RunState.MAP; _assert(game._resume_formal_run() and game.state == game.RunState.REST, "rest state should round-trip")
	_assert(game.choose_service("upgrade"), "service selection should open before saving")
	_assert(game._save_run_now(), "service card selection should save")
	game.pending_card_selection.clear()
	_assert(game._resume_formal_run() and game.state == game.RunState.REST and str(game.pending_card_selection.get("owner", "")) == "service", "service card selection should round-trip")
	_assert(game.choose_pending_card(0), "restored service selection should resolve")
	game._open_component_choice(); _assert(game._save_run_now(), "component state should save")
	game.component_choices.clear(); _assert(game._resume_formal_run() and game.state == game.RunState.COMPONENT and game.component_choices.size() == 3, "component choices should round-trip")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("environment_baseline")]
	game.processing_points = 3
	_assert(game.play_card(0), "rapid-save fixture should begin card animation")
	game.card_action_queue.append({"kind": "test_pending_animation"})
	_assert(!game._save_run_now(), "save should wait while card animations are pending")
	game.card_action_queue.clear()
	_assert(!game._card_actions_pending() and game._save_run_now(), "save should run after the final card settles")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_assert(!game._has_valid_run_save() and !FileAccess.file_exists(SAVE_PATH), "corrupt saves should be discarded")
	game._apply_settings({"sfxEnabled": false, "sfxVolume": 0.2, "animationSpeed": 1.5, "reducedFlash": true})
	var stored = game.SettingsStore.load(SETTINGS_PATH)
	_assert(stored == {"sfxEnabled": false, "sfxVolume": 0.2, "animationSpeed": 1.5, "reducedFlash": true}, "settings should persist through the root API")
	_assert(is_equal_approx(game.motion_duration_scale, 2.0 / 3.0) and game.reduced_flash, "settings should update live animation and flash behavior")

	game.queue_free()
	await process_frame
	_cleanup()
	if failures > 0:
		quit(1)
	else:
		print("Ch09 run persistence flow tests passed")
		quit(0)


func _cleanup() -> void:
	for path in [SAVE_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
