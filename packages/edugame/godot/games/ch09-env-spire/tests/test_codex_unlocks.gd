extends SceneTree

var failures := 0
var record_path := "user://ch09_codex_unlock_test_%d.cfg" % Time.get_ticks_msec()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish(null)
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.codex_record_path = record_path
	game.codex_progress = {"version": 1, "cards": [], "faults": []}

	_assert_card_discovery(game)
	_assert_fault_discovery(game)
	_assert_boss_discovery(game)
	_finish(game)


func _assert_card_discovery(game) -> void:
	game._start_tutorial_encounter()
	_assert(!game.play_card(0), "tutorial card should be rejected before its guided step")
	_assert(!_is_unlocked(game, "cards", "sliding_average"), "rejected cards must stay locked")
	_assert(game.confirm_tutorial_intent(), "tutorial intent confirmation should advance the guided step")
	_assert(game.play_card(0), "guided tutorial card should settle")
	_assert(_is_unlocked(game, "cards", "sliding_average"), "a settled tutorial card should unlock")


func _assert_fault_discovery(game) -> void:
	game.tutorial_active = false
	game._reset_run()
	game._start_encounter("bh1750_stale", "ordinary")
	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.state == game.RunState.COMBAT, "missing evidence should keep the encounter active")
	_assert(!_is_unlocked(game, "faults", "bh1750_stale"), "failed evidence validation must not unlock a fault")

	game._start_encounter("mq2_warmup", "ordinary")
	game.repair_progress = game.repair_target
	for raw_group in game.current_encounter.get("evidenceGroups", []):
		var group := raw_group as Array
		if !group.is_empty():
			game.encounter_evidence_tags[str(group[0])] = true
	game._finish_encounter()
	_assert(game.state == game.RunState.REWARD, "validated repair should open the reward")
	_assert(_is_unlocked(game, "faults", "mq2_warmup"), "validated repair should unlock its fault")


func _assert_boss_discovery(game) -> void:
	game._reset_run()
	game.formal_run_active = false
	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game.repair_progress = game.repair_target
	game.phase_source_coverage = {"smoke": true, "light": true}
	game._finish_encounter()
	_assert(game.boss_phase == 1, "first accepted Boss phase should advance")
	_assert(!_is_unlocked(game, "faults", "warehouse_acceptance"), "Boss must stay locked before final acceptance")

	game.boss_phase = 2
	game._apply_boss_phase()
	game.repair_progress = game.repair_target
	game.phase_output_types = {"display": true, "uart": true}
	game._finish_encounter()
	_assert(game.state == game.RunState.RESULT and game.victory, "final Boss acceptance should finish the run")
	_assert(_is_unlocked(game, "faults", "warehouse_acceptance"), "final Boss acceptance should unlock the Boss")


func _is_unlocked(game, kind: String, content_id: String) -> bool:
	return (game.codex_progress.get(kind, []) as Array).has(content_id)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _cleanup() -> void:
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(record_path))


func _finish(game) -> void:
	_cleanup()
	if is_instance_valid(game):
		game.queue_free()
	if failures == 0:
		print("Ch09 codex unlock tests passed")
	quit(1 if failures > 0 else 0)
