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
	get_root().add_child(game)
	await process_frame
	await process_frame

	game._reset_run()
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()

	var feedback_layer = game.find_child("CombatFeedbackLayer", true, false) as CanvasLayer
	var feedback_root = game.find_child("CombatFeedbackRoot", true, false) as Control
	var feedback_banner = game.find_child("CombatFeedbackBanner", true, false) as PanelContainer
	var feedback_title = game.find_child("CombatFeedbackTitle", true, false) as Label
	var feedback_detail = game.find_child("CombatFeedbackDetail", true, false) as Label
	var feedback_flash = game.find_child("CombatFeedbackFlash", true, false) as ColorRect
	var sound_toggle = game.find_child("CombatSoundToggle", true, false) as BaseButton
	var feedback_audio = game.find_child("CombatFeedbackAudio", true, false) as AudioStreamPlayer
	var boss_phase_overlay = game.find_child("BossPhaseOverlay", true, false) as Control
	var boss_phase_title = game.find_child("BossPhaseTitle", true, false) as Label
	var boss_phase_subtitle = game.find_child("BossPhaseSubtitle", true, false) as Label
	_assert(feedback_layer != null, "combat should build an isolated feedback CanvasLayer")
	_assert(feedback_root != null and feedback_root.theme == game.ui_theme, "feedback CanvasLayer should explicitly inherit the bundled Chinese UI theme")
	_assert(feedback_banner != null and feedback_title != null and feedback_detail != null, "combat feedback should expose stable banner nodes")
	_assert(feedback_flash != null, "combat feedback should expose a non-interactive flash layer")
	_assert(sound_toggle != null and feedback_audio != null, "combat feedback should expose sound controls")
	_assert(boss_phase_overlay != null and boss_phase_title != null and boss_phase_subtitle != null, "combat should expose a dedicated Boss phase transition overlay")
	if boss_phase_overlay != null:
		_assert(boss_phase_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Boss phase transitions should never intercept combat input")
		_assert(!boss_phase_overlay.visible, "Boss phase transition overlay should start hidden")
	for marker_index in range(1, 4):
		_assert(game.find_child("BossPhaseMarker%d" % marker_index, true, false) != null, "Boss transition should expose phase marker %d" % marker_index)
	if sound_toggle != null:
		_assert(sound_toggle.text == "SFX ON", "sound control should expose its enabled state without relying on color")
	if feedback_flash != null:
		_assert(feedback_flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "feedback flash should never intercept input")

	var feedback_contract_available: bool = (
		game.has_method("combat_feedback_snapshot")
		and game.has_method("clear_combat_feedback_history")
		and game.has_method("set_combat_sound_enabled")
		and game.has_method("is_combat_sound_enabled")
	)
	_assert(feedback_contract_available, "combat should expose a testable semantic feedback contract")
	var queue_contract_available: bool = game.has_method("combat_feedback_queue_size")
	_assert(queue_contract_available, "combat should expose queued visual-feedback state for deterministic tests")
	var cue_profile_contract_available: bool = game.has_method("combat_feedback_cue_profile")
	_assert(cue_profile_contract_available, "combat should expose deterministic cue profiles for sound regression tests")
	if cue_profile_contract_available:
		var cue_signatures := {}
		for cue in ["card", "chain", "repair", "weakness", "damage", "suppressed", "fault", "boss_1", "boss_2", "boss_3", "reward"]:
			var profile := game.combat_feedback_cue_profile(cue) as Dictionary
			var notes := profile.get("notes", []) as Array
			_assert(!notes.is_empty(), "cue %s should contain at least one note" % cue)
			var signature := JSON.stringify(profile)
			_assert(!cue_signatures.has(signature), "cue %s should have a distinct sound profile" % cue)
			cue_signatures[signature] = cue

	game.clear_combat_feedback_history()
	game._emit_combat_feedback(
		"fault_triggered",
		"Fault triggered",
		"Local feedback must not hide the rule or counter.",
		Color("#b75a3a"),
		"fault"
	)
	await process_frame
	await process_frame
	var fault_core = game.find_child("FaultCoreVisual", true, false) as Control
	var fault_rule = game.find_child("FaultRuleRow", true, false) as Control
	var fault_counter = game.find_child("FaultCounterRow", true, false) as Control
	if feedback_banner != null and fault_core != null and fault_rule != null and fault_counter != null:
		var banner_rect := feedback_banner.get_global_rect()
		_assert(banner_rect.intersects(fault_core.get_global_rect()), "fault feedback should anchor to the fault core: banner=%s core=%s anchors=%s/%s offsets=%s/%s/%s/%s" % [banner_rect, fault_core.get_global_rect(), feedback_banner.anchor_left, feedback_banner.anchor_top, feedback_banner.offset_left, feedback_banner.offset_top, feedback_banner.offset_right, feedback_banner.offset_bottom])
		_assert(!banner_rect.intersects(fault_rule.get_global_rect()), "fault feedback should not cover the fault rule: banner=%s rule=%s" % [banner_rect, fault_rule.get_global_rect()])
		_assert(!banner_rect.intersects(fault_counter.get_global_rect()), "fault feedback should not cover the counter guidance: banner=%s counter=%s" % [banner_rect, fault_counter.get_global_rect()])
	game.clear_combat_feedback_history()

	game.hand = [game._card_copy("led_alarm")]
	game.processing_points = 3
	game.trusted_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	game.alarm_markers = 0
	game._render_state()
	var unavailable_card = game.find_child("HandCard_led_alarm_0", true, false) as Button
	_assert(unavailable_card != null and unavailable_card.disabled, "unmet card requirements should disable the card")
	if unavailable_card != null:
		_assert(unavailable_card.text.contains("不可用"), "disabled cards should state why they cannot be played")

	if feedback_contract_available:
		game.clear_combat_feedback_history()
		game._start_encounter("mq2_warmup", "ordinary")
		game.hand = [game._card_copy("mq2_sample")]
		game.processing_points = 3
		game.repair_progress = 0
		_assert(game.play_card(0), "feedback fixture should play a real collection card")
		var card_events := _events_of_kind(game.combat_feedback_snapshot(), "card")
		var repair_events := _events_of_kind(game.combat_feedback_snapshot(), "repair")
		var weakness_events := _events_of_kind(game.combat_feedback_snapshot(), "weakness")
		_assert(card_events.size() == 1, "one played card should emit one card feedback event")
		if card_events.size() == 1:
			var card_event := card_events[0] as Dictionary
			_assert(str(card_event.get("cardId", "")) == "mq2_sample", "card feedback should identify the played card")
			_assert(str(card_event.get("chainDecision", "")) == "advances", "card feedback should identify the chain decision")
		_assert(repair_events.size() == 1 and int((repair_events[0] as Dictionary).get("amount", 0)) == 4, "repair feedback should report the exact positive delta")
		_assert(weakness_events.size() == 1, "matching an encounter weakness should emit one semantic weakness event")
		if weakness_events.size() == 1:
			var weakness_event := weakness_events[0] as Dictionary
			_assert((weakness_event.get("matchedTags", []) as Array).has("smoke"), "weakness feedback should identify the matched knowledge tag")
			_assert(int(weakness_event.get("diagnosisBonus", -1)) == 0, "weakness feedback should report the exact diagnosis bonus")
		_assert(feedback_title.text.contains(str(game.card_defs["mq2_sample"].get("name", ""))), "the first visible feedback should retain the played-card result")
		if queue_contract_available:
			_assert(game.combat_feedback_queue_size() == 2, "repair and weakness feedback should queue instead of immediately replacing the card result")
		await create_timer(0.85).timeout
		_assert(feedback_title.text.contains("+4"), "queued repair feedback should become visible after the card result")

		game.clear_combat_feedback_history()
		game.stability = game.max_stability
		game.block = 2
		game._take_damage(6)
		var stability_events := _events_of_kind(game.combat_feedback_snapshot(), "stability")
		_assert(stability_events.size() == 1, "unblocked damage should emit one stability feedback event")
		if stability_events.size() == 1:
			_assert(int((stability_events[0] as Dictionary).get("amount", 0)) == -4, "stability feedback should report damage after block")

		game.clear_combat_feedback_history()
		game._start_encounter("mq2_warmup", "ordinary")
		game.raw_data["smoke"] = 1
		game.hand = [game._card_copy("adc_convert")]
		game.processing_points = 3
		_assert(game.play_card(0), "fault suppression fixture should play a real counter card")
		_assert(_events_of_kind(game.combat_feedback_snapshot(), "fault_suppressed").size() == 1, "counterplay should emit a fault-suppressed event")

		game.clear_combat_feedback_history()
		game._start_encounter("mq2_warmup", "ordinary")
		game.hand = [game._card_copy("mq2_sample"), game._card_copy("mq2_sample")]
		game.processing_points = 3
		_assert(game.play_card(0), "fault trigger fixture should play its first collection card")
		_assert(game.play_card(0), "fault trigger fixture should play its second collection card")
		_assert(_events_of_kind(game.combat_feedback_snapshot(), "fault_triggered").size() == 1, "triggered rules should emit a fault-triggered event")

		game.clear_combat_feedback_history()
		game._emit_combat_feedback("card", "Stale card cue", "Should be replaced by Boss phase", Color("#2f7f8d"), "card")
		_assert(feedback_banner != null and feedback_banner.visible, "stale-banner fixture should begin with a visible ordinary cue")
		game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
		game.boss_phase = 0
		game._start_encounter("warehouse_acceptance", "boss")
		var boss_events := _events_of_kind(game.combat_feedback_snapshot(), "boss_phase")
		_assert(boss_events.size() == 1, "entering the Boss should announce its first phase")
		if boss_events.size() == 1:
			_assert(int((boss_events[0] as Dictionary).get("phase", 0)) == 1, "Boss feedback should use reader-facing phase numbers")
		if boss_phase_overlay != null and boss_phase_title != null and boss_phase_subtitle != null:
			_assert(boss_phase_overlay.visible, "entering a Boss phase should display the transition overlay")
			_assert(feedback_banner != null and !feedback_banner.visible, "Boss phase transition should fully replace stale ordinary feedback banners")
			_assert(int(boss_phase_overlay.get_meta("phase", 0)) == 1, "Boss phase overlay should expose its active phase for visual regression tests")
			_assert(boss_phase_title.text.contains("PHASE 1 OF 3"), "Boss transition should state the current phase explicitly")
			_assert(!boss_phase_subtitle.text.is_empty(), "Boss transition should name the current acceptance stage")

		_assert(game.set_combat_sound_enabled(false), "sound control should accept disabling")
		_assert(!game.is_combat_sound_enabled(), "sound control should report disabled state")
		if sound_toggle != null:
			_assert(!sound_toggle.button_pressed, "sound toggle should mirror disabled state")
			_assert(sound_toggle.text == "SFX OFF", "sound toggle should expose its disabled state in text")
		_assert(game.set_combat_sound_enabled(true), "sound control should accept enabling")
		_assert(game.is_combat_sound_enabled(), "sound control should report enabled state")
		if sound_toggle != null:
			_assert(sound_toggle.text == "SFX ON", "sound toggle should restore its enabled-state text")

	game.queue_free()
	await process_frame
	_finish()


func _events_of_kind(events: Array, kind: String) -> Array:
	var result: Array = []
	for raw_event in events:
		var event := raw_event as Dictionary
		if str(event.get("kind", "")) == kind:
			result.append(event)
	return result


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 combat feedback tests passed")
	quit(1 if failures > 0 else 0)
