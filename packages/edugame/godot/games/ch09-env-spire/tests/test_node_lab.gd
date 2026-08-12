extends SceneTree

const REQUIRED_STATIC_IDS := [
	"boss_phase_1", "boss_phase_2", "boss_phase_3",
	"sensor_checkpoint", "trust_checkpoint", "component",
	"service", "ordinary_reward", "elite_reward"
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
	get_root().size = Vector2i(1280, 720)
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(1280, 720)
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
	var catalog_title = game.find_child("NodeLabCatalogTitle", true, false) as Label
	var run_hud = game.find_child("RunHud", true, false)
	var return_button = game.find_child("NodeLabReturn", true, false)
	var restart_button = game.find_child("NodeLabRestart", true, false)
	var force_correct_button = game.find_child("NodeLabForceCorrect", true, false)
	var force_wrong_button = game.find_child("NodeLabForceWrong", true, false)
	var lab_toolbar = game.find_child("NodeLabToolbar", true, false) as Control
	var lab_frame = game.find_child("NodeLabTacticalFrame", true, false) as Control
	var debug_button = game.find_child("NodeLabDebugButton", true, false) as Button
	var debug_panel = game.find_child("NodeLabDebugPanel", true, false) as Control
	var debug_scroll = game.find_child("NodeLabDebugScroll", true, false) as ScrollContainer
	var debug_close = game.find_child("NodeLabDebugClose", true, false) as Button
	var card_selector = game.find_child("NodeLabCardSelector", true, false) as OptionButton
	var add_card_button = game.find_child("NodeLabAddCard", true, false) as Button
	var stability_input = game.find_child("NodeLabStabilityInput", true, false) as SpinBox
	var apply_stability_button = game.find_child("NodeLabApplyStability", true, false) as Button
	var fault_remaining_input = game.find_child("NodeLabFaultRemainingInput", true, false) as SpinBox
	var apply_fault_button = game.find_child("NodeLabApplyFaultRemaining", true, false) as Button
	var hand_list = game.find_child("NodeLabHandList", true, false) as VBoxContainer
	var deck_list = game.find_child("NodeLabDeckList", true, false) as VBoxContainer
	var arena = game.find_child("EncounterArena", true, false)
	var hand_dock = game.find_child("HandDock", true, false)
	_assert(lab_root != null and lab_root.theme == game.ui_theme, "lab root should use the game UI theme")
	_assert(catalog != null and catalog.visible and !game.shell.visible, "catalog should hide the normal shell")
	_assert(lab_frame != null and str(lab_frame.call("visual_signature")).contains("tactical_hud"), "node lab catalog should use the out-of-run tactical HUD frame")
	var catalog_style := catalog.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(catalog_style != null and catalog_style.bg_color.get_luminance() > 0.78, "node lab catalog should use the shared light layout surface")
	_assert(catalog_title != null and catalog_title.get_theme_color("font_color").get_luminance() < 0.25, "node lab catalog heading should use dark text on the light surface")
	_assert(run_hud != null and run_hud.visible and game.shell.offset_top == 0.0, "catalog should restore the normal header position")
	_assert(debug_button != null and !debug_button.visible, "catalog should hide the scenario-only debug button")
	_assert(debug_panel != null and !debug_panel.visible, "catalog should keep the debug panel closed")

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
		_assert(game.pending_service_energy_penalty == 0, "lab fixture should clear queued service costs")
		_assert(game.relics.is_empty(), "lab fixture should clear components")
		_assert(_entry_reached_expected_state(game, entry), "%s should reach its expected state" % entry.get("id", "scenario"))
		if game.state == game.RunState.COMBAT:
			var fixture_visual = game.find_child("FaultCoreVisual", true, false)
			_assert(fixture_visual != null and fixture_visual.has_method("visual_snapshot"), "%s should bind the production fault visual" % entry.get("id", "scenario"))
			if fixture_visual != null and fixture_visual.has_method("visual_snapshot"):
				var visual_snapshot := fixture_visual.visual_snapshot() as Dictionary
				_assert(str(visual_snapshot.get("encounterId", "")) == str(game.current_encounter.get("id", "")), "%s should render the active encounter signature" % entry.get("id", "scenario"))
				_assert(!str(fixture_visual.get_visual_signature()).is_empty(), "%s should expose a non-empty visual signature" % entry.get("id", "scenario"))
				if str(game.current_encounter.get("tier", "")) == "boss":
					_assert(int(visual_snapshot.get("bossPhase", -1)) == game.boss_phase, "%s should render the requested Boss phase" % entry.get("id", "scenario"))

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
		var rule_id := str(game._fault_rule_definition().get("id", ""))
		_assert(_execute_fault_path(game, rule_id, false), "%s trigger fixture should execute" % rule_id)
		_assert(_fault_trigger_observed(game, rule_id), "%s trigger fixture should report triggered" % rule_id)
		_assert(bool(game.restart_lab_scenario()), "fault-rule fixture should restart")
		_assert(_hand_ids(game.hand) == first_hand, "fault-rule fixture hand should be deterministic")
		_assert(_execute_fault_path(game, rule_id, true), "%s counter fixture should execute" % rule_id)
		_assert(_fault_suppression_observed(game, rule_id), "%s counter fixture should report suppressed" % rule_id)

	var coverage_entry := _entry(entries, "mq2_warmup")
	_assert(bool(game.start_lab_scenario(coverage_entry, "coverage")), "coverage fixture should launch")
	await process_frame
	for tag in COVERAGE_TAGS:
		_assert(game._deck_has_any_tag([tag]), "coverage fixture should contain tag %s" % tag)
	var debug_method_names := [
		"lab_add_card_to_hand",
		"lab_remove_hand_card",
		"lab_remove_deck_card",
		"lab_set_stability",
		"lab_set_fault_remaining",
		"lab_fault_remaining"
	]
	var debug_methods_available := true
	for method_name in debug_method_names:
		var has_debug_method: bool = game.has_method(method_name)
		_assert(has_debug_method, "Node Lab should expose %s" % method_name)
		debug_methods_available = debug_methods_available and has_debug_method
	if debug_methods_available:
		var hand_size_before_add: int = game.hand.size()
		_assert(game.lab_add_card_to_hand("logic_probe"), "debug control should add a selected card directly to hand")
		_assert(
			game.hand.size() == hand_size_before_add + 1
				and str((game.hand[-1] as Dictionary).get("id", "")) == "logic_probe",
			"debug-added card should be an immediately playable copy"
		)
		var hand_after_valid_add: Array = game.hand.duplicate(true)
		_assert(!game.lab_add_card_to_hand("missing_debug_card"), "debug control should reject an unknown card")
		_assert(game.hand == hand_after_valid_add, "rejected debug card should not mutate hand")
		_assert(game.lab_remove_hand_card(game.hand.size() - 1), "debug control should remove one indexed hand card")
		_assert(game.hand.size() == hand_size_before_add, "hand-card removal should remove exactly one card")
		var hand_after_valid_remove: Array = game.hand.duplicate(true)
		_assert(!game.lab_remove_hand_card(999), "debug control should reject an invalid hand index")
		_assert(game.hand == hand_after_valid_remove, "invalid hand index should not mutate hand")

		game.deck.append(game._card_copy("logic_probe"))
		game.deck.append(game._card_copy("logic_probe"))
		var deck_probe_count_before := _count_card_id(game.deck, "logic_probe")
		_assert(game.lab_remove_deck_card("logic_probe"), "debug control should remove a selected deck card")
		_assert(
			_count_card_id(game.deck, "logic_probe") == deck_probe_count_before - 1,
			"deck-card removal should remove exactly one matching instance"
		)
		var deck_after_valid_remove: Array = game.deck.duplicate(true)
		_assert(!game.lab_remove_deck_card("missing_debug_card"), "debug control should reject a missing deck card")
		_assert(game.deck == deck_after_valid_remove, "missing deck card should not mutate deck")

		_assert(game.lab_set_stability(999), "debug control should accept stability changes")
		_assert(game.stability == game.max_stability, "debug stability should clamp to max stability")
		_assert(game.lab_set_stability(-5), "debug control should accept low stability changes")
		_assert(game.stability == 1, "debug stability should clamp to one")
		_assert(game.lab_set_fault_remaining(5), "debug control should accept remaining fault value during combat")
		_assert(
			game.repair_progress == game.repair_target - 5 and game.lab_fault_remaining() == 5,
			"remaining fault value should convert to repair progress"
		)
		_assert(game.lab_set_fault_remaining(999), "debug control should clamp excessive remaining fault value")
		_assert(game.repair_progress == 0 and game.lab_fault_remaining() == game.repair_target, "remaining fault value should clamp to repair target")
		_assert(game.lab_set_fault_remaining(-5), "debug control should clamp negative remaining fault value")
		_assert(
			game.repair_progress == game.repair_target
				and game.lab_fault_remaining() == 0
				and game.state == game.RunState.COMBAT,
			"zero remaining fault value should update combat without auto-resolving it"
		)
		game.encounter_evidence_tags = {"smoke": true, "calibration": true}
		var stability_before_debug_completion: int = game.stability
		_assert(game.end_turn(), "normal end-turn action should accept a zero-remaining debug state")
		_assert(game.state == game.RunState.REWARD, "ending the turn at zero remaining value should resolve the encounter")
		_assert(game.stability == stability_before_debug_completion, "debug-complete encounter should resolve before the fault acts")
		_assert(game.restart_lab_scenario(), "debug completion fixture should restart for remaining control checks")

		var boss_entry := _entry(entries, "boss_phase_2")
		_assert(game.start_lab_scenario(boss_entry, "coverage"), "boss gate regression fixture should launch")
		_assert(!game._boss_phase_requirements_met(), "boss gate regression fixture should begin without phase evidence")
		_assert(game.lab_set_fault_remaining(0), "boss gate regression fixture should allow zero remaining fault")
		var boss_turn_before: int = game.turn_number
		_assert(game.end_turn(), "boss turn should still end when repair is complete but phase evidence is missing")
		_assert(game.state == game.RunState.COMBAT, "boss should remain in combat until phase evidence is complete")
		_assert(game.turn_number == boss_turn_before + 1, "unmet boss evidence should advance to the next turn")

		var hand_before_guard: Array = game.hand.duplicate(true)
		game.node_lab_active = false
		_assert(!game.lab_add_card_to_hand("logic_probe"), "debug card mutation should be rejected outside Node Lab")
		_assert(game.hand == hand_before_guard, "rejected formal-mode mutation should leave hand unchanged")
		_assert(game.lab_fault_remaining() == -1, "debug remaining-value getter should be unavailable outside Node Lab")
		game.node_lab_active = true
		game.state = game.RunState.REST
		var repair_before_non_combat: int = game.repair_progress
		_assert(!game.lab_set_fault_remaining(3), "remaining fault value should be rejected outside combat")
		_assert(game.repair_progress == repair_before_non_combat, "rejected non-combat value should not change repair progress")
		game.state = game.RunState.COMBAT
	var debug_ui_available := (
		debug_button != null
		and debug_panel != null
		and debug_scroll != null
		and debug_close != null
		and card_selector != null
		and add_card_button != null
		and stability_input != null
		and apply_stability_button != null
		and fault_remaining_input != null
		and apply_fault_button != null
		and hand_list != null
		and deck_list != null
	)
	_assert(debug_ui_available, "Node Lab should build the complete debug-control panel")
	if debug_ui_available:
		_assert(debug_button.visible, "scenario should expose the debug-panel command")
		debug_button.emit_signal("pressed")
		await process_frame
		_assert(debug_panel.visible and debug_panel.is_visible_in_tree(), "debug command should open the panel")
		var logic_probe_index := _option_index_for_metadata(card_selector, "logic_probe")
		_assert(logic_probe_index >= 0, "card selector should include every formal card")
		if logic_probe_index >= 0:
			card_selector.select(logic_probe_index)
			var hand_before_ui_add: int = game.hand.size()
			add_card_button.emit_signal("pressed")
			await process_frame
			_assert(
				game.hand.size() == hand_before_ui_add + 1
					and str((game.hand[-1] as Dictionary).get("id", "")) == "logic_probe",
				"debug panel should add the selected card directly to hand"
			)
			_assert(hand_list.get_child_count() == game.hand.size(), "hand list should refresh after adding a card")
			var delete_added_card = game.find_child("NodeLabDeleteHand_%d" % (game.hand.size() - 1), true, false) as Button
			_assert(delete_added_card != null, "each hand card should expose a deletion command")
			if delete_added_card != null:
				delete_added_card.emit_signal("pressed")
				await process_frame
				_assert(game.hand.size() == hand_before_ui_add, "hand deletion command should remove the selected card")

		stability_input.value = 12
		apply_stability_button.emit_signal("pressed")
		await process_frame
		_assert(game.stability == 12, "stability input should apply its exact in-range value")
		fault_remaining_input.value = 7
		apply_fault_button.emit_signal("pressed")
		await process_frame
		_assert(game.lab_fault_remaining() == 7, "fault input should apply the requested remaining value")

		var deck_card_id := str((game.deck[0] as Dictionary).get("id", ""))
		var deck_card_count_before := _count_card_id(game.deck, deck_card_id)
		var delete_deck_card = game.find_child("NodeLabDeleteDeck_%s" % deck_card_id, true, false) as Button
		_assert(delete_deck_card != null, "each deck card type should expose a deletion command")
		if delete_deck_card != null:
			delete_deck_card.emit_signal("pressed")
			await process_frame
			_assert(_count_card_id(game.deck, deck_card_id) == deck_card_count_before - 1, "deck deletion command should remove one matching card")
			_assert(deck_list.get_child_count() > 0, "deck list should remain rendered after deletion")

		game.state = game.RunState.REST
		lab.refresh_debug_panel()
		_assert(!fault_remaining_input.editable and apply_fault_button.disabled, "non-combat scenarios should disable fault-value controls")
		game.state = game.RunState.COMBAT
		lab.refresh_debug_panel()
		_assert(fault_remaining_input.editable and !apply_fault_button.disabled, "combat scenarios should enable fault-value controls")

		var desktop_viewport := Rect2(Vector2.ZERO, game.size)
		_assert(
			desktop_viewport.encloses(debug_panel.get_global_rect()),
			"desktop debug panel should remain viewport-contained: panel=%s viewport=%s"
			% [debug_panel.get_global_rect(), desktop_viewport]
		)

		debug_close.emit_signal("pressed")
		await process_frame
		_assert(!debug_panel.visible, "close command should hide the debug panel")
		debug_button.emit_signal("pressed")
		await process_frame
		restart_button.emit_signal("pressed")
		await process_frame
		_assert(!debug_panel.visible, "restarting a scenario should close the debug panel")
	_assert(catalog != null and !catalog.visible, "scenario should hide the catalog")
	_assert(return_button != null and return_button.visible and restart_button != null and restart_button.visible, "scenario should expose the lab toolbar controls")
	_assert(run_hud != null and !run_hud.visible and game.shell.visible and game.shell.offset_top == lab_toolbar.size.y, "scenario toolbar should replace RunHud using its resolved height")
	_assert(arena != null and arena.is_visible_in_tree() and hand_dock != null and hand_dock.is_visible_in_tree(), "lab combat should expose the redesigned arena and hand dock")

	var fixture_hand_ids := _hand_ids(game.hand)
	var fixture_deck_ids := _hand_ids(game.deck)
	var fixture_repair_progress: int = game.repair_progress
	_assert(game.lab_add_card_to_hand("logic_probe"), "reset test should mutate the fixture hand")
	var removed_fixture_deck_id := str((game.deck[0] as Dictionary).get("id", ""))
	_assert(game.lab_remove_deck_card(removed_fixture_deck_id), "reset test should mutate the fixture deck")
	_assert(game.lab_set_fault_remaining(4), "reset test should mutate fixture repair progress")
	game.stability = 3
	game.pending_service_energy_penalty = -2
	game.relics = ["pullup_4k7"]
	var runtime_calls: Array = []
	game.runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: runtime_calls.append(payload))
	_assert(bool(game.restart_lab_scenario()), "restart should relaunch the current scenario")
	await process_frame
	_assert(game.stability == game.max_stability and game.pending_service_energy_penalty == 0, "restart should restore fixture resources")
	_assert(game.relics.is_empty(), "restart should clear scenario components")
	_assert(_hand_ids(game.hand) == fixture_hand_ids, "restart should restore the fixture hand")
	_assert(_hand_ids(game.deck) == fixture_deck_ids, "restart should restore the fixture deck")
	_assert(game.repair_progress == fixture_repair_progress, "restart should restore fixture repair progress")
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
		var menu_return := game.find_child("NodeLabReturn", true, false) as Button
		_assert(menu_return != null and menu_return.visible and menu_return.text.contains("菜单"), "lab catalog should expose a menu return")
		if menu_return != null:
			menu_return.pressed.emit()
			await process_frame
			_assert(game.state == game.RunState.MENU and !game.node_lab_active, "lab menu return should restore MENU")

	game.queue_free()
	await process_frame
	_finish()


func _entry_reached_expected_state(game, entry: Dictionary) -> bool:
	match str(entry.get("kind", "")):
		"enemy", "boss_phase", "boss_gate", "checkpoint_sensor", "checkpoint_trust", "fault_rule":
			return game.state == game.RunState.COMBAT
		"event", "question_event", "question_correct", "question_wrong":
			return game.state == game.RunState.EVENT
		"component":
			return game.state == game.RunState.COMPONENT
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
		var matches_trigger := true
		var has_card_trigger := !trigger_tag.is_empty() or !trigger_stage.is_empty()
		if !trigger_tag.is_empty() and !tags.has(trigger_tag):
			matches_trigger = false
		if !trigger_stage.is_empty() and str(card.get("stage", "")) != trigger_stage:
			matches_trigger = false
		if has_card_trigger and matches_trigger:
			trigger_count += 1
		elif !trigger_source.is_empty() and tags.has(trigger_source):
			trigger_count += 1
		for raw_tag in counter_tags:
			if tags.has(str(raw_tag)):
				has_counter = true
	return trigger_count >= required_count and has_counter


func _execute_fault_path(game, rule_id: String, use_counter: bool) -> bool:
	match rule_id:
		"mq2_uncalibrated":
			if use_counter and !_play_card_id(game, "environment_baseline"):
				return false
			return _play_card_id(game, "mq2_sample") and _play_card_id(game, "mq2_sample")
		"bh1750_stale_raw":
			if use_counter and !_play_card_id(game, "data_cache"):
				return false
			if !_play_card_id(game, "bh1750_read"):
				return false
			return game.end_turn()
		"adc_second_collect":
			if use_counter and !_play_card_id(game, "outlier_reject"):
				return false
			return _play_card_id(game, "mq2_sample") and _play_card_id(game, "bh1750_read")
		"lcd_unprepared_output":
			if use_counter and !_play_card_id(game, "data_cache"):
				return false
			return _play_card_id(game, "lcd_display")
		"alarm_without_trust":
			if use_counter and !_play_card_id(game, "sliding_average"):
				return false
			return _play_card_id(game, "led_alarm")
		"i2c_second_transaction":
			if use_counter and !_play_card_id(game, "environment_baseline"):
				return false
			return _play_card_id(game, "i2c_transaction") and _play_card_id(game, "i2c_transaction")
		"mq2_baseline_drift":
			if use_counter and !_play_card_id(game, "environment_baseline"):
				return false
			return _play_card_id(game, "mq2_sample")
		"bh1750_early_read":
			if use_counter and !_play_card_id(game, "task_yield"):
				return false
			return _play_card_id(game, "bh1750_read")
		"hdc1080_conversion_wait":
			if use_counter and !_play_card_id(game, "task_yield"):
				return false
			return _play_card_id(game, "i2c_transaction") and _play_card_id(game, "i2c_transaction")
		"i2c_address_collision":
			if use_counter and !_play_card_id(game, "logic_probe"):
				return false
			return _play_card_id(game, "i2c_transaction")
		"uart_frame_overrun":
			if use_counter and !_play_card_id(game, "task_yield"):
				return false
			return _play_card_id(game, "interrupt_trace") and _play_card_id(game, "interrupt_trace")
		"multi_sensor_race":
			if use_counter and !_play_card_id(game, "task_yield"):
				return false
			return _play_card_id(game, "mq2_sample") and _play_card_id(game, "bh1750_read")
		"display_bus_deadlock":
			if use_counter and !_play_card_id(game, "task_yield"):
				return false
			return _play_card_id(game, "lcd_display")
	return false


func _play_card_id(game, card_id: String) -> bool:
	for index in range(game.hand.size()):
		if str((game.hand[index] as Dictionary).get("id", "")) == card_id:
			return game.play_card(index)
	return false


func _fault_trigger_observed(game, rule_id: String) -> bool:
	if rule_id == "bh1750_stale_raw":
		return _log_contains(game.message_log, "Fault rule %s triggered" % rule_id)
	return bool(game.fault_rule_state.get("triggered", false)) and !bool(game.fault_rule_state.get("suppressed", false))


func _fault_suppression_observed(game, rule_id: String) -> bool:
	if rule_id == "bh1750_stale_raw":
		return _log_contains(game.message_log, "Fault rule %s suppressed" % rule_id)
	return bool(game.fault_rule_state.get("suppressed", false)) and !bool(game.fault_rule_state.get("triggered", false))


func _log_contains(entries: Array, expected: String) -> bool:
	for entry in entries:
		if str(entry).contains(expected):
			return true
	return false


func _hand_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_card in cards:
		ids.append(str((raw_card as Dictionary).get("id", "")))
	return ids


func _count_card_id(cards: Array, expected_id: String) -> int:
	var count := 0
	for raw_card in cards:
		if str((raw_card as Dictionary).get("id", "")) == expected_id:
			count += 1
	return count


func _option_index_for_metadata(selector: OptionButton, expected_id: String) -> int:
	for item_index in range(selector.item_count):
		if str(selector.get_item_metadata(item_index)) == expected_id:
			return item_index
	return -1


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
