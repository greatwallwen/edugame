extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual_script = load("res://scripts/env_spire_combat_visual.gd")
	_assert(visual_script != null, "combat visual script should load")
	if visual_script == null:
		_finish()
		return
	var palette_probe = visual_script.new()
	get_root().add_child(palette_probe)
	_assert(palette_probe.has_method("surface_palette"), "combat visual should expose its console surface palette")
	if palette_probe.has_method("surface_palette"):
		var surface_palette := palette_probe.surface_palette() as Dictionary
		_assert((surface_palette.get("background", Color.WHITE) as Color).get_luminance() < 0.12, "combat instrument backgrounds should remain dark")
		_assert((surface_palette.get("label", Color.BLACK) as Color).get_luminance() > 0.70, "combat labels should stay readable on dark instruments")
	_assert(palette_probe.has_method("fault_art_contract"), "combat visual should expose its fault art contract")
	if palette_probe.has_method("fault_art_contract"):
		var art_contract := palette_probe.fault_art_contract() as Dictionary
		_assert(str(art_contract.get("style", "")) == "flat_electronic_target", "fault targets should use the approved flat electronic art language")
		_assert(int(art_contract.get("minimumTraceWidth", 0)) >= 3, "fault target traces should read as crisp graphic paths instead of thin wireframes")
		_assert(int(art_contract.get("tonalSteps", 99)) <= 3, "fault targets should use a restrained flat tonal hierarchy")
		_assert(int(art_contract.get("textPlateBorderWidth", -1)) == 0, "text plates should use solid surfaces without outlines touching glyphs")
		_assert(int(art_contract.get("minimumTextPadding", 0)) >= 6, "text plates should keep visible padding around every glyph")
		_assert(!bool(art_contract.get("redundantTopLabels", true)), "generated frame rails should not carry redundant English labels")
	_assert(palette_probe.has_method("enemy_art_path"), "combat visual should expose deterministic enemy art lookup")
	var enemy_art_ids := [
		"mq2_warmup",
		"bh1750_stale",
		"adc_spike",
		"lcd_blocking",
		"alarm_jitter",
		"mq2_baseline_drift",
		"bh1750_early_read",
		"hdc1080_conversion_wait",
		"i2c_address_collision",
		"uart_frame_overrun",
		"i2c_congestion",
		"multi_sensor_race",
		"display_bus_deadlock",
		"warehouse_acceptance"
	]
	if palette_probe.has_method("enemy_art_path"):
		for enemy_id in enemy_art_ids:
			var art_path := str(palette_probe.enemy_art_path(enemy_id))
			_assert(art_path == "res://assets/enemy-art/%s.png" % enemy_id, "%s should resolve to its dedicated enemy artwork" % enemy_id)
			var enemy_texture = load(art_path) as Texture2D
			_assert(enemy_texture != null, "%s artwork should import as a Godot texture" % enemy_id)
			if enemy_texture != null:
				var texture_size := enemy_texture.get_size()
				_assert(texture_size.x >= 768.0 and texture_size.y >= 512.0, "%s artwork should retain enough source detail for its 560 x 150 desktop stage" % enemy_id)
				_assert(absf(texture_size.x / texture_size.y - 1.5) < 0.02, "%s artwork should use the shared 3:2 composition" % enemy_id)
		_assert(str(palette_probe.enemy_art_path("sensor_checkpoint")).is_empty(), "non-enemy checkpoints should keep the procedural visual fallback")
	_assert(palette_probe.has_method("fault_text_layout"), "fault visuals should expose a border-safe text layout")
	_assert(palette_probe.has_method("content_safe_rect"), "combat visuals should separate decorative frame space from content space")
	if palette_probe.has_method("fault_text_layout") and palette_probe.has_method("content_safe_rect"):
		palette_probe.size = Vector2(560, 176)
		var safe_rect := palette_probe.content_safe_rect() as Rect2
		var text_layout := palette_probe.fault_text_layout() as Dictionary
		_assert(safe_rect.position.x >= 12.0 and safe_rect.position.y >= 20.0, "standard combat content should clear the decorative frame rails")
		for key in ["heading", "intent"]:
			_assert(!(text_layout.get(key, Rect2()) as Rect2).has_area(), "%s should be omitted instead of being placed beside the top rail" % key)
		for key in ["condition", "state"]:
			var text_rect := text_layout.get(key, Rect2()) as Rect2
			_assert(text_rect.has_area(), "%s should use a dedicated text plate" % key)
			_assert(text_rect.size.y >= 24.0, "%s text plate should be tall enough to keep glyphs clear of its edges" % key)
			_assert(_rect_inside(text_rect, safe_rect), "%s text plate should remain inside the content safe area" % key)
			_assert(text_rect.end.y <= safe_rect.end.y - 18.0, "%s text plate should clear the generated frame's lower rail" % key)
		_assert(!(text_layout.get("condition", Rect2()) as Rect2).intersects(text_layout.get("state", Rect2()) as Rect2), "condition and state plates should never overlap")
		palette_probe.size = Vector2(280, 84)
		var compact_layout := palette_probe.fault_text_layout() as Dictionary
		for key in ["heading", "intent", "condition", "state"]:
			_assert(!(compact_layout.get(key, Rect2()) as Rect2).has_area(), "compact reward visuals should omit %s instead of placing it on the frame" % key)
	_assert(palette_probe.has_method("localized_signal_labels"), "combat visual should expose localized signal labels for regression coverage")
	if palette_probe.has_method("localized_signal_labels"):
		var signal_labels := palette_probe.localized_signal_labels() as Dictionary
		_assert(signal_labels.get("sources", []) == ["烟", "光", "温", "湿"], "device source labels should render valid Chinese glyphs")
		_assert(signal_labels.get("stages", []) == ["采", "接", "理", "出"], "evidence stage labels should render valid Chinese glyphs")
	palette_probe.queue_free()
	await process_frame

	var backdrop_script = load("res://scripts/env_spire_backdrop.gd")
	_assert(backdrop_script != null, "console backdrop should load independently")
	if backdrop_script != null:
		var backdrop = backdrop_script.new()
		_assert(backdrop is TextureRect and backdrop.texture != null, "persistent backdrop should expose the illustrated laboratory texture")
		_assert(backdrop.has_method("visual_signature") and str(backdrop.visual_signature()).contains("ambient_lab"), "backdrop should identify the quiet environmental laboratory art direction")
		var left_veil = backdrop.find_child("AmbientLeftColorVeil", true, false) as ColorRect
		var right_veil = backdrop.find_child("AmbientRightColorVeil", true, false) as ColorRect
		_assert(left_veil != null and right_veil != null, "ambient backdrop should soften both outer equipment zones")
		if left_veil != null and right_veil != null:
			_assert(left_veil.anchor_right <= 0.20 and right_veil.anchor_left >= 0.80, "ambient veils should preserve the central stage")
			_assert(left_veil.color.a >= 0.14 and left_veil.color.a <= 0.22, "ambient veil strength should stay subtle")
			_assert(left_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and right_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ambient veils should never consume input")
		backdrop.queue_free()

	var stage_script = load("res://scripts/env_spire_combat_stage.gd")
	var frame_script = load("res://scripts/env_spire_tech_frame.gd")
	_assert(stage_script != null and frame_script != null, "combat should provide dedicated stage and corner-frame visuals")
	if stage_script != null:
		var stage_probe = stage_script.new()
		_assert(stage_probe.has_method("visual_signature") and str(stage_probe.visual_signature()).contains("triad"), "combat stage should identify the three-way confrontation composition")
		var stage_palette := stage_probe.stage_palette() as Dictionary
		_assert((stage_palette.get("device", Color.GRAY) as Color).s > 0.65, "device stage should use a vivid cyan signal color")
		_assert((stage_palette.get("fault", Color.GRAY) as Color).r > 0.85, "fault stage should use a vivid red signal color")
		stage_probe.queue_free()
	if frame_script != null:
		var frame_probe = frame_script.new()
		_assert(frame_probe.has_method("set_profile"), "tech frame should switch between hardware and tactical profiles")
		_assert(frame_probe.has_method("hardware_art_path"), "tech frame should expose its generated hardware art asset")
		if frame_probe.has_method("hardware_art_path"):
			var hardware_art_path := str(frame_probe.hardware_art_path())
			_assert(hardware_art_path == "res://assets/ui/in-run-electronic-frame-flat-slim-v5.png", "in-run frame should use the slim flat electronic art asset")
			_assert(load(hardware_art_path) != null, "generated in-run frame art should import as a Godot texture")
		_assert(frame_probe.has_method("hardware_art_paths"), "tech frame should expose both generated aspect-ratio assets")
		if frame_probe.has_method("hardware_art_paths"):
			var art_paths := frame_probe.hardware_art_paths() as Dictionary
			_assert(str(art_paths.get("support", "")) == "res://assets/ui/in-run-electronic-frame-flat-slim-v5.png", "support zones should use the slim flat near-square frame")
			_assert(str(art_paths.get("fault", "")) == "res://assets/ui/in-run-electronic-frame-flat-slim-wide-v5.png", "fault zones should use the matching slim flat wide frame")
			_assert(load(str(art_paths.get("fault", ""))) != null, "generated wide frame art should import as a Godot texture")
		_assert(frame_probe.has_method("content_safe_insets"), "generated tech frames should expose content-safe insets")
		if frame_probe.has_method("content_safe_insets"):
			frame_probe.configure("fault", Color("#ff5f57"))
			var fault_insets := frame_probe.content_safe_insets() as Dictionary
			_assert(float(fault_insets.get("top", 0.0)) >= 60.0 and float(fault_insets.get("top", 0.0)) <= 68.0, "wide fault art should keep headings fully below its top rail")
		if frame_probe.has_method("set_profile"):
			frame_probe.set_profile("hardware")
			_assert(str(frame_probe.visual_signature()).contains("flat_slim_electronic_art"), "in-run frames should identify the slim flat electronic art profile")
			frame_probe.set_profile("tactical")
			_assert(str(frame_probe.visual_signature()).contains("tactical_hud"), "out-of-run frames should identify the tactical HUD profile")
		frame_probe.queue_free()

	var signatures := {}
	for fixture in [
		{"id": "mq2_warmup", "tier": "ordinary", "weaknessTags": ["smoke", "calibration"]},
		{"id": "adc_spike", "tier": "ordinary", "weaknessTags": ["adc", "filter"]},
		{"id": "i2c_congestion", "tier": "elite", "weaknessTags": ["i2c", "scheduler"]},
		{"id": "warehouse_acceptance", "tier": "boss", "bossPhase": 1, "weaknessTags": ["acceptance", "filter"]}
	]:
		var visual = visual_script.new()
		get_root().add_child(visual)
		_assert(visual.has_method("configure"), "combat visual should expose configure")
		_assert(visual.has_method("set_snapshot"), "combat visual should expose set_snapshot")
		_assert(visual.has_method("get_visual_signature"), "combat visual should expose deterministic signatures")
		visual.configure("fault", null)
		visual.set_snapshot(fixture)
		signatures[str(fixture.get("id", ""))] = str(visual.get_visual_signature())
		_assert(str(visual.get_visual_signature()).contains("flat_electronic_target"), "%s should use the flat electronic target signature" % fixture.get("id", "fixture"))
		visual.queue_free()
		await process_frame
	_assert(signatures.values().duplicate().size() == 4, "combat fixtures should record four signatures")
	var unique_signatures := {}
	for signature in signatures.values():
		unique_signatures[str(signature)] = true
	_assert(unique_signatures.size() == 4, "MQ-2, ADC, I2C and Boss should have distinct visual signatures")
	for fixture in [
		{"id": "mq2_warmup", "tier": "ordinary"},
		{"id": "bh1750_stale", "tier": "ordinary"},
		{"id": "adc_spike", "tier": "ordinary"},
		{"id": "lcd_blocking", "tier": "ordinary"},
		{"id": "alarm_jitter", "tier": "ordinary"},
		{"id": "i2c_congestion", "tier": "elite"},
		{"id": "sensor_checkpoint", "tier": "checkpoint"},
		{"id": "trust_checkpoint", "tier": "checkpoint"}
	]:
		var coverage_visual = visual_script.new()
		get_root().add_child(coverage_visual)
		coverage_visual.size = Vector2(280, 176)
		coverage_visual.configure("fault", null)
		coverage_visual.set_snapshot(fixture)
		_assert(!str(coverage_visual.get_visual_signature()).contains("generic_fault"), "%s should have a dedicated visual motif" % fixture.get("id", "fixture"))
		await process_frame
		coverage_visual.queue_free()
		await process_frame
	var boss_signatures := {}
	for phase in range(3):
		var boss_visual = visual_script.new()
		get_root().add_child(boss_visual)
		boss_visual.size = Vector2(320, 176)
		boss_visual.configure("fault", null)
		boss_visual.set_snapshot({"id": "warehouse_acceptance", "tier": "boss", "bossPhase": phase})
		boss_signatures[str(boss_visual.get_visual_signature())] = true
		await process_frame
		boss_visual.queue_free()
		await process_frame
	_assert(boss_signatures.size() == 3, "all three Boss phases should expose distinct visual signatures")

	var condition_visual = visual_script.new()
	get_root().add_child(condition_visual)
	condition_visual.configure("fault", null)
	_assert(condition_visual.has_method("fault_condition"), "fault visuals should expose deterministic repair condition states")
	if condition_visual.has_method("fault_condition"):
		var condition_cases := [
			{"progress": 0, "target": 30, "expected": "unstable"},
			{"progress": 11, "target": 30, "expected": "isolated"},
			{"progress": 21, "target": 30, "expected": "stabilizing"},
			{"progress": 30, "target": 30, "expected": "restored"}
		]
		var condition_signatures := {}
		for condition_case in condition_cases:
			condition_visual.set_snapshot({
				"id": "adc_spike",
				"tier": "ordinary",
				"repairProgress": condition_case.get("progress", 0),
				"repairTarget": condition_case.get("target", 1)
			})
			_assert(condition_visual.fault_condition() == condition_case.get("expected", ""), "%s repair ratio should map to %s" % [condition_case.get("progress", 0), condition_case.get("expected", "")])
			condition_signatures[condition_visual.get_visual_signature()] = true
		condition_visual.set_snapshot({"id": "adc_spike", "tier": "ordinary", "repairProgress": 0, "repairTarget": 30, "resolved": true})
		_assert(condition_visual.fault_condition() == "restored", "resolved snapshots should always render restored")
		_assert(condition_signatures.size() == 4, "fault signatures should distinguish all repair condition states")
	condition_visual.queue_free()
	await process_frame

	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().size = Vector2i(1280, 720)
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	game._start_clean_formal_run()
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()
	await process_frame

	var device_visual = game.find_child("DeviceTelemetryVisual", true, false)
	var evidence_visual = game.find_child("EvidenceSignalVisual", true, false)
	var fault_visual = game.find_child("FaultCoreVisual", true, false)
	var enemy_intent = game.find_child("EnemyIntent", true, false) as Control
	var device_unit = game.find_child("DeviceUnit", true, false) as Control
	var evidence_bridge = game.find_child("EvidenceBridge", true, false) as Control
	var fault_unit = game.find_child("FaultUnit", true, false) as Control
	var fault_body = game.find_child("FaultBody", true, false) as Control
	var stage_visual = game.find_child("CombatStageVisual", true, false) as Control
	var device_frame = game.find_child("DeviceTechFrame", true, false) as Control
	var evidence_frame = game.find_child("EvidenceTechFrame", true, false) as Control
	var fault_frame = game.find_child("FaultTechFrame", true, false) as Control
	_assert(device_visual != null and evidence_visual != null and fault_visual != null, "combat should expose three production visual anchors")
	_assert(enemy_intent is Button and enemy_intent.has_method("configure_intent"), "enemy intent should use the compact clickable badge component")
	_assert(device_unit != null and evidence_bridge != null and fault_unit != null and fault_body != null, "combat should expose three weighted arena zones and a bounded fault body")
	_assert(stage_visual != null and device_frame != null and evidence_frame != null and fault_frame != null, "combat arena should expose its stage field and three non-interactive corner frames")
	if device_frame != null:
		_assert(str(device_frame.call("visual_signature")).contains("flat_slim_electronic_art"), "combat should use the slim flat in-run electronic frame profile")
		var hardware_art = device_frame.find_child("HardwareFrameArt", false, false) as TextureRect
		_assert(hardware_art != null and hardware_art.texture != null, "combat hardware frame should render its generated texture")
		if hardware_art != null:
			_assert(hardware_art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "generated hardware art should never intercept combat input")
			_assert(hardware_art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "flat frame art should use non-mipmapped linear sampling so ventilation holes stay crisp")
			_assert(hardware_art.offset_left <= -24.0 and hardware_art.offset_top <= -24.0, "support electronic art should compensate for generated transparent padding")
		var fault_hardware_art = fault_frame.find_child("HardwareFrameArt", false, false) as TextureRect
		_assert(fault_hardware_art != null and fault_hardware_art.texture.resource_path.contains("wide"), "fault combat zone should render the generated wide frame instead of stretching support art")
		_assert(fault_frame.get_parent() == fault_unit, "fault frame should be clipped by the enemy panel without disappearing")
		_assert(fault_frame.z_index <= 0 and fault_frame.get_index() == 0, "fault frame should render behind enemy content instead of becoming the top layer")
		if fault_hardware_art != null:
			_assert(fault_hardware_art.offset_left <= -34.0 and fault_hardware_art.offset_left >= -46.0 and fault_hardware_art.offset_top <= -26.0, "wide electronic art should align its slim outer rail with the fault panel")
	if device_unit != null and evidence_bridge != null and fault_unit != null:
		_assert(
			fault_unit.size_flags_stretch_ratio >= device_unit.size_flags_stretch_ratio * 1.8
			and fault_unit.size_flags_stretch_ratio >= evidence_bridge.size_flags_stretch_ratio * 1.8,
			"fault zone should carry roughly twice the horizontal visual weight of each support zone"
		)
		_assert(evidence_bridge.get_global_rect().position.x - device_unit.get_global_rect().end.x >= 14.0, "arena zones should keep enough space that borders never visually merge")
		var device_style := device_unit.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(device_style != null and device_style.content_margin_left >= 14.0 and device_style.content_margin_top >= 24.0 and device_style.content_margin_top <= 32.0 and device_style.border_width_left <= 1, "support zones should reclaim space from the slimmer electronic frame without stacking a second border")
		var evidence_style := evidence_bridge.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(device_style.bg_color.get_luminance() > 0.72 and evidence_style.bg_color.get_luminance() > 0.72, "support zones should remain light even after tutorial focus rendering")
		var fault_style := fault_unit.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(fault_style != null and fault_style.content_margin_top >= 60.0 and fault_style.content_margin_top <= 68.0, "fault content should clear the top rail without text touching the frame")
		_assert(fault_unit.offset_bottom <= -40.0, "fault panel fill should stop inside the generated frame's transparent lower trim")
		_assert(fault_unit.clip_contents, "fault unit should clip unexpected child overflow at its content boundary")
		var encounter_title = game.find_child("EncounterName", true, false) as Label
		if encounter_title != null:
			var title_offset := encounter_title.get_global_rect().position.y - fault_unit.get_global_rect().position.y
			_assert(title_offset >= 60.0 and title_offset <= 72.0, "encounter title should sit below the top rail without touching it")
		if fault_body != null:
			_assert(fault_body.custom_minimum_size.y <= 156.0, "fault body should fit the remaining space while reclaiming the removed intent row")
			_assert(fault_body.get_global_rect().end.y <= fault_unit.get_global_rect().end.y - 8.0, "fault body should remain fully above the enemy panel's lower frame")
	if stage_visual != null:
		_assert(stage_visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "combat stage should never intercept input")
	var end_turn := game.find_child("EndTurnButton", true, false) as Button
	if end_turn != null:
		var end_turn_style := end_turn.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(end_turn_style != null and end_turn_style.border_width_left >= 3 and end_turn_style.corner_radius_top_left <= 3, "end turn should use the dedicated sci-fi command treatment")
	if fault_visual != null:
		_assert(fault_visual.custom_minimum_size.y <= 156.0, "fault artwork should use the vertical space reclaimed from the old intent strip")
		_assert(fault_visual.get_global_rect().end.y <= fault_unit.get_global_rect().end.y - 8.0, "fault artwork should never extend through the enemy frame")
	if fault_visual != null and enemy_intent != null:
		_assert(enemy_intent.get_parent().name == "FaultArtStack", "enemy intent should float in the artwork overlay instead of occupying a full-width layout row")
		_assert(enemy_intent.size.x <= 154.0 and enemy_intent.size.y <= 42.0, "floating enemy intent should keep its compact footprint")
		_assert(fault_visual.get_global_rect().encloses(enemy_intent.get_global_rect()), "floating intent should remain fully inside the enemy artwork")
	for visual in [device_visual, evidence_visual, fault_visual]:
		if visual == null:
			continue
		_assert(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s should never intercept combat input" % visual.name)
		_assert(visual.has_method("visual_snapshot"), "%s should expose its bound snapshot" % visual.name)
	if fault_visual != null:
		var snapshot := fault_visual.visual_snapshot() as Dictionary
		_assert(str(snapshot.get("encounterId", "")) == "mq2_warmup", "fault visual should bind the active encounter")
		_assert(str(snapshot.get("intentType", "")) == "negative", "fault visual should bind the active intent")

	_assert(game.has_method("_card_visual_target"), "root should expose deterministic card animation targeting")
	if game.has_method("_card_visual_target"):
		for expected_target in [
			{"types": ["collect", "interface"], "target": "device"},
			{"types": ["process", "defense", "power"], "target": "evidence"},
			{"types": ["output"], "target": "fault"}
		]:
			for card_type in expected_target.get("types", []):
				_assert(game._card_visual_target({"type": card_type}) == expected_target.get("target"), "%s cards should target %s visuals" % [card_type, expected_target.get("target")])

	var hand_row = game.find_child("HandRow", true, false)
	var motion_layer = game.find_child("CombatMotionLayer", true, false)
	_assert(hand_row != null and hand_row.get_child_count() > 0 and motion_layer != null, "combat should expose a source card and motion layer")
	if hand_row != null and hand_row.get_child_count() > 0 and motion_layer != null:
		game._animate_card_play(hand_row.get_child(0) as Control, game.hand[0] as Dictionary)
		await process_frame
		_assert(motion_layer.get_child_count() == 1, "playing a card should create one semantic motion ghost")
		if motion_layer.get_child_count() == 1:
			_assert(str(motion_layer.get_child(0).name).begins_with("CardMotion_"), "card motion ghost should use a stable debug name")
		await create_timer(0.5).timeout
		_assert(motion_layer.get_child_count() == 0, "card motion ghost should clean itself up after the tween")

	var reward_device = game.find_child("ResolvedDeviceVisual", true, false)
	var reward_evidence = game.find_child("ResolvedEvidenceVisual", true, false)
	var reward_fault = game.find_child("ResolvedFaultVisual", true, false)
	_assert(reward_device != null and reward_evidence != null and reward_fault != null, "reward flow should reuse all three visual modes")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x \
		and inner.position.y >= outer.position.y \
		and inner.end.x <= outer.end.x \
		and inner.end.y <= outer.end.y


func _finish() -> void:
	if failures == 0:
		print("Ch09 combat visual tests passed")
	quit(1 if failures > 0 else 0)
