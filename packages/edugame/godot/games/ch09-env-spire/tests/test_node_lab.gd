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
const BASIC_EVENT_GROUP := "基础题事件"
const ADVANCED_EVENT_GROUP := "进阶题事件"
const QUESTION_RESULT_GROUP := "题目结果"
const FAULT_RULE_GROUP := "故障规则"

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
	var force_correct_button = game.find_child("NodeLabForceCorrect", true, false)
	var force_wrong_button = game.find_child("NodeLabForceWrong", true, false)
	var arena = game.find_child("EncounterArena", true, false)
	var hand_dock = game.find_child("HandDock", true, false)
	_assert(lab_root != null and lab_root.theme == game.ui_theme, "lab root should use the game UI theme")
	_assert(catalog != null and catalog.visible and !game.shell.visible, "catalog should hide the normal shell")
	_assert(run_hud != null and run_hud.visible and game.shell.offset_top == 0.0, "catalog should restore the normal header position")

	var basic_events := _entries_in_group(entries, BASIC_EVENT_GROUP)
	var advanced_events := _entries_in_group(entries, ADVANCED_EVENT_GROUP)
	var result_entries := _entries_in_group(entries, QUESTION_RESULT_GROUP)
	var fault_entries := _entries_in_group(entries, FAULT_RULE_GROUP)
	_assert(basic_events.size() == 8, "Node Lab should expose eight basic question events")
	_assert(advanced_events.size() == 8, "Node Lab should expose eight advanced question events")
	_assert(_has_entry(result_entries, "question_correct") and _has_entry(result_entries, "question_wrong"), "Node Lab should expose correct and wrong result fixtures")
	for raw_entry in basic_events + advanced_events:
		var question_entry := raw_entry as Dictionary
		_assert(str(question_entry.get("kind", "")) == "question_event", "question catalog entries should use the question-event fixture kind")
		_assert(!str(question_entry.get("questionType", "")).is_empty(), "question catalog entries should retain their question type")
	var non_boss_fault_count := 0
	for raw_enemy in game.enemy_defs.values():
		var enemy := raw_enemy as Dictionary
		if str(enemy.get("tier", "")) != "boss" and !(enemy.get("faultRule", {}) as Dictionary).is_empty():
			non_boss_fault_count += 1
	_assert(fault_entries.size() == non_boss_fault_count, "Node Lab should expose one fault-rule fixture per non-Boss fault")
	_assert(force_correct_button != null and force_wrong_button != null, "Node Lab should expose forced correct and wrong controls")

	for enemy_id in game.enemy_defs.keys():
		_assert(_has_entry(entries, str(enemy_id)), "lab should include enemy %s" % enemy_id)
	for event_id in game.event_defs.keys():
		_assert(_has_entry(entries, str(event_id)), "lab should include event %s" % event_id)
	for required_id in REQUIRED_STATIC_IDS:
		_assert(_has_entry(entries, required_id), "lab should include %s" % required_id)

	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		_assert(bool(game.start_lab_scenario(entry, "starter")), "lab should launch %s" % entry.get("id", "scenario"))
		if str(entry.get("kind", "")) == "question_wrong":
			_assert(game.stability < game.max_stability, "wrong result fixture should expose its applied penalty")
		else:
			_assert(game.stability == game.max_stability, "lab fixture should restore full stability")
		_assert(game.budget == 100, "lab fixture should provide deterministic budget")
		_assert(game.relics.is_empty(), "lab fixture should clear components")
		_assert(_entry_reached_expected_state(game, entry), "%s should reach its expected state" % entry.get("id", "scenario"))

	if !basic_events.is_empty() and force_correct_button != null and force_wrong_button != null:
		var question_entry := basic_events[0] as Dictionary
		_assert(bool(game.start_lab_scenario(question_entry, "starter")), "question fixture should launch")
		var correct_answer = _duplicate_variant(game.current_event.get("correctAnswer"))
		_assert(force_correct_button.visible and force_wrong_button.visible, "question fixture should show forced outcome controls")
		force_correct_button.emit_signal("pressed")
		await process_frame
		_assert(game.event_answer_locked and bool(game.event_result.get("correct", false)), "correct control should force the correct result")
		_assert(game.current_event.get("correctAnswer") == correct_answer, "correct control should not mutate the underlying answer")
		_assert(bool(game.restart_lab_scenario()), "question fixture should restart")
		force_wrong_button.emit_signal("pressed")
		await process_frame
		_assert(game.event_answer_locked and !bool(game.event_result.get("correct", true)), "wrong control should force the wrong result")
		_assert(game.current_event.get("correctAnswer") == correct_answer, "wrong control should not mutate the underlying answer")

	for raw_entry in fault_entries:
		var fault_entry := raw_entry as Dictionary
		_assert(bool(game.start_lab_scenario(fault_entry, "starter")), "fault-rule fixture should launch")
		_assert(!game._fault_rule_preview().is_empty(), "fault-rule fixture should expose its preview")
		_assert(_fault_hand_supports_rule(game), "fault-rule fixture should include trigger and counter paths")
		var first_hand := _hand_ids(game.hand)
		_assert(bool(game.restart_lab_scenario()), "fault-rule fixture should restart")
		_assert(_hand_ids(game.hand) == first_hand, "fault-rule fixture hand should be deterministic")

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
		"enemy", "boss_phase", "checkpoint_sensor", "checkpoint_trust", "fault_rule":
			return game.state == game.RunState.COMBAT
		"event", "question_event", "question_correct", "question_wrong":
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


func _entries_in_group(entries: Array, expected_group: String) -> Array:
	return entries.filter(func(raw_entry) -> bool:
		return str((raw_entry as Dictionary).get("group", "")) == expected_group
	)


func _fault_hand_supports_rule(game) -> bool:
	var rule := game._fault_rule_definition() as Dictionary
	var trigger_count := 0
	var required_count := int(rule.get("triggerCount", 1))
	var trigger_tag := str(rule.get("triggerTag", ""))
	var trigger_stage := str(rule.get("triggerStage", ""))
	var trigger_source := str(rule.get("source", ""))
	var has_counter := false
	var counter_tags: Array = rule.get("counterTags", [])
	for raw_card in game.hand:
		var card := raw_card as Dictionary
		var tags: Array = card.get("tags", [])
		if !trigger_tag.is_empty() and tags.has(trigger_tag):
			trigger_count += 1
		elif !trigger_stage.is_empty() and str(card.get("stage", "")) == trigger_stage:
			trigger_count += 1
		elif !trigger_source.is_empty() and tags.has(trigger_source):
			trigger_count += 1
		for raw_tag in counter_tags:
			if tags.has(str(raw_tag)):
				has_counter = true
	return trigger_count >= required_count and has_counter


func _hand_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_card in cards:
		ids.append(str((raw_card as Dictionary).get("id", "")))
	return ids


func _duplicate_variant(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


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
