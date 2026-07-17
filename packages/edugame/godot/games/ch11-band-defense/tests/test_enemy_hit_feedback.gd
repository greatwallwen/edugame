extends SceneTree

const HitFeedbackFx = preload("res://scripts/hit_feedback_fx.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reaction_profiles()
	_test_visual_readability_profile()
	_test_recoil_shadow_profile()
	_test_health_states()
	_test_reaction_transform_is_visual_only()
	_test_deterministic_impact_event()
	_test_tower_signatures()
	_test_density_caps()
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load for lifecycle coverage")
	if scene != null:
		var game = scene.instantiate()
		root.add_child(game)
		await process_frame
		_test_game_lifecycle(game)
		_test_hover_health(game)
		game.queue_free()
	if failures > 0:
		quit(1)
	else:
		print("enemy hit feedback tests passed")
		quit(0)


func _test_reaction_profiles() -> void:
	var matched := HitFeedbackFx.reaction_profile(true)
	var mismatched := HitFeedbackFx.reaction_profile(false)
	_assert(float(matched.get("recoilPx", 0.0)) > float(mismatched.get("recoilPx", 0.0)), "matched hits should recoil farther")
	_assert(float(matched.get("compression", 1.0)) < float(mismatched.get("compression", 1.0)), "matched hits should compress more")
	_assert(int(matched.get("particleCount", 0)) == 0, "matched hits should not create micro sparks or debris")
	_assert(int(mismatched.get("particleCount", 0)) == 0, "mismatched hits should not create micro sparks or debris")


func _test_visual_readability_profile() -> void:
	var matched := HitFeedbackFx.impact_visual_profile(true)
	var mismatched := HitFeedbackFx.impact_visual_profile(false)
	_assert(float(matched.get("maxBloomSize", 99.0)) <= 54.0, "matched bloom should stay smaller than the enemy body")
	_assert(float(matched.get("maxAlpha", 1.0)) <= 0.64, "matched bloom should not wash out enemy details")
	_assert(float(mismatched.get("maxBloomSize", 99.0)) < float(matched.get("maxBloomSize", 0.0)), "mismatched bloom should remain visibly weaker")
	_assert(float(mismatched.get("maxAlpha", 1.0)) < float(matched.get("maxAlpha", 0.0)), "mismatched bloom should remain visibly dimmer")
	_assert(float(matched.get("contactOffset", 0.0)) >= 10.0, "impact light should sit near the contacted edge rather than over the body center")


func _test_recoil_shadow_profile() -> void:
	var idle := HitFeedbackFx.shadow_profile(1.0)
	var reacting := HitFeedbackFx.shadow_profile(0.94)
	_assert(is_zero_approx(float(idle.get("alpha", 1.0))), "idle enemies should not keep a detached shadow below the route")
	_assert(float(reacting.get("offsetY", 99.0)) <= 18.0, "recoil shadow should stay close to the enemy route anchor")
	_assert(float(reacting.get("alpha", 1.0)) <= 0.12, "recoil shadow should remain visually secondary")


func _test_health_states() -> void:
	_assert(HitFeedbackFx.health_state(70.0, 100.0) == "stable", "health above sixty percent should be stable")
	_assert(HitFeedbackFx.health_state(60.0, 100.0) == "damaged", "sixty percent health should be damaged")
	_assert(HitFeedbackFx.health_state(25.0, 100.0) == "damaged", "twenty-five percent health should remain damaged")
	_assert(HitFeedbackFx.health_state(24.0, 100.0) == "critical", "health below twenty-five percent should be critical")
	_assert(HitFeedbackFx.health_state(0.0, 0.0) == "critical", "zero maximum health should remain safe and critical")


func _test_reaction_transform_is_visual_only() -> void:
	var enemy := {
		"progress": 112.0,
		"hitReactionTtl": HitFeedbackFx.IMPACT_DURATION * 0.72,
		"hitReactionDuration": HitFeedbackFx.IMPACT_DURATION,
		"hitDirection": Vector2.RIGHT,
		"lastMatched": true,
	}
	var progress_before := float(enemy.progress)
	var transform := HitFeedbackFx.reaction_transform(enemy)
	_assert((transform.get("offset", Vector2.ZERO) as Vector2).x < 0.0, "body should recoil opposite the incoming direction")
	_assert(float(transform.get("scale", 1.0)) < 1.0, "matched body should briefly compress")
	_assert(is_equal_approx(float(enemy.progress), progress_before), "visual recoil must never change route progress")


func _test_deterministic_impact_event() -> void:
	var first := HitFeedbackFx.make_impact_event(Vector2(210, 180), Vector2.RIGHT, "peak", true, 24.0, false, 17)
	var second := HitFeedbackFx.make_impact_event(Vector2(210, 180), Vector2.RIGHT, "peak", true, 24.0, false, 17)
	_assert((first.get("particles", []) as Array).is_empty(), "impact events should contain no micro sparks or debris")
	_assert(first.get("particles", []) == second.get("particles", []), "particle-free impact events should remain deterministic")
	_assert(str(first.get("towerId", "")) == "peak", "impact should retain tower identity")
	_assert(is_equal_approx(float(first.get("duration", 0.0)), HitFeedbackFx.IMPACT_DURATION), "impact duration should match the motion envelope")


func _test_tower_signatures() -> void:
	var expected := {
		"i2c": "scan_bracket",
		"filter": "noise_damping",
		"peak": "threshold_flash",
		"power": "power_clamp",
	}
	for tower_id in expected:
		var profile := HitFeedbackFx.signature_profile(tower_id)
		_assert(str(profile.get("kind", "")) == str(expected[tower_id]), "%s should retain a distinct impact signature" % tower_id)
	var mismatch := HitFeedbackFx.impact_color("i2c", false)
	var matched := HitFeedbackFx.impact_color("i2c", true)
	_assert((mismatch as Color).r > (mismatch as Color).g, "mismatched response should read as warm red-orange")
	_assert((matched as Color).g > (matched as Color).r, "matched I2C response should retain cool diagnostic color")


func _test_density_caps() -> void:
	var events: Array = []
	for index in range(31):
		events.append(HitFeedbackFx.make_impact_event(Vector2(index * 4, 80), Vector2.RIGHT, "filter", index % 4 != 0, 8.0, false, index + 1))
	var deaths: Array = []
	for index in range(16):
		deaths.append({"ttl": HitFeedbackFx.DEATH_DURATION, "serial": index})
	HitFeedbackFx.enforce_caps(events, deaths)
	var particle_total := 0
	for event in events:
		particle_total += (event as Dictionary).get("particles", []).size()
	_assert(events.size() <= HitFeedbackFx.MAX_IMPACTS, "impact count should be capped")
	_assert(particle_total == 0, "visible hit particles should remain disabled")
	_assert(deaths.size() <= HitFeedbackFx.MAX_DEATHS, "death echo count should be capped")


func _test_game_lifecycle(game) -> void:
	_assert(game.has_method("_clear_enemy_hit_feedback"), "game should centralize transient hit cleanup")
	_assert(game.get("hit_effects") is Array, "game should expose capped impact event storage")
	_assert(game.get("death_echoes") is Array, "game should keep visual death echoes outside active enemies")
	_assert(game.has_method("_draw_enemy_hit_effects"), "game should draw localized enemy impact effects")
	_assert(game.has_method("_draw_death_echoes"), "game should draw visual-only death echoes")
	var root_source := FileAccess.get_file_as_string("res://scripts/band_defense_root.gd")
	var feedback_source := FileAccess.get_file_as_string("res://scripts/hit_feedback_fx.gd")
	var draw_start := root_source.find("func _draw() -> void:")
	var backplate_draw := root_source.find("\t_draw_enemy_hit_backplates()", draw_start)
	var enemy_draw := root_source.find("\t_draw_enemies()", draw_start)
	var foreground_draw := root_source.find("\t_draw_enemy_hit_effects()", draw_start)
	_assert(!root_source.contains("SymptomFx.draw_hit_pulse"), "legacy full circular hit pulse should be removed")
	_assert(!root_source.contains("spark_origin"), "enemy damage states should not draw micro sparks")
	_assert(!root_source.contains("fragment_pos"), "death echoes should not draw fault debris")
	_assert(!feedback_source.contains("_draw_particles"), "impact rendering should not include micro particle drawing")
	_assert(!feedback_source.contains("_draw_noise_sink"), "filter impact identity should use clean damping arcs instead of particle-like dots")
	_assert(!feedback_source.contains("_draw_threshold_spark"), "peak impact identity should use a clean pulse instead of sparks")
	_assert(backplate_draw >= 0 and backplate_draw < enemy_draw, "localized impact bloom should render behind enemy bodies")
	_assert(foreground_draw > enemy_draw, "compact tower signatures should remain visible in front of enemy bodies")
	if !(game.get("hit_effects") is Array) or !(game.get("death_echoes") is Array):
		return
	game.enemies.clear()
	game.hit_effects.clear()
	game.death_echoes.clear()
	var enemy := {
		"type": "false_peak",
		"threatTag": "false_peak",
		"hp": 1.0,
		"maxHp": 100.0,
		"reward": 9,
		"progress": 120.0,
		"pos": Vector2(420, 260),
		"diagnosed": true,
		"reached": false,
		"symptomPhase": 0.0,
	}
	game.enemies.append(enemy)
	var slot := {
		"pos": Vector2(320, 260),
		"tower": {"id": "peak", "level": 1, "cooldown": 0.0, "attackAnim": 0.0},
	}
	var energy_before := int(game.energy)
	var data_before := int(game.trusted_data)
	game._fire_tower(slot, slot.tower, game.tower_defs.peak, enemy)
	_assert(game.hit_effects.size() == 1, "firing should create one enemy impact event")
	_assert(float(enemy.get("hitReactionTtl", 0.0)) > 0.0, "firing should start visual-only body reaction")
	_assert(is_equal_approx(float(enemy.progress), 120.0), "firing should not move route progress")
	game._cleanup_dead_enemies()
	_assert(game.enemies.is_empty(), "lethal enemy should leave targeting immediately")
	_assert(game.death_echoes.size() == 1, "lethal enemy should leave one visual-only death echo")
	_assert(int(game.energy) == energy_before + 9, "lethal reward should be granted immediately")
	_assert(int(game.trusted_data) == data_before + 1, "lethal trusted data should be granted immediately")
	game._clear_enemy_hit_feedback()
	_assert(game.hit_effects.is_empty() and game.death_echoes.is_empty(), "central cleanup should clear transient visuals")
	_assert(game.get("hovered_enemy") == null, "central cleanup should clear hover target")


func _test_hover_health(game) -> void:
	_assert(game.has_method("_find_hovered_enemy"), "game should resolve one hover target")
	_assert(game.has_method("_enemy_health_readout"), "game should format exact health on demand")
	_assert(game.has_method("_hover_health_chip_rect"), "game should clamp the hover chip to the map safe area")
	_assert(game.has_method("_draw_hover_health_chip"), "game should draw one hover-only glass health chip")
	if !game.has_method("_find_hovered_enemy") or !game.has_method("_enemy_health_readout") or !game.has_method("_hover_health_chip_rect"):
		return
	var lower_progress := {"hp": 68.0, "maxHp": 120.0, "pos": Vector2(440, 250), "progress": 90.0, "reached": false}
	var higher_progress := {"hp": 40.0, "maxHp": 100.0, "pos": Vector2(460, 250), "progress": 130.0, "reached": false}
	game.enemies = [lower_progress, higher_progress]
	var hovered = game._find_hovered_enemy(Vector2(450, 250))
	_assert(hovered == higher_progress, "equal-distance overlap should prefer greatest route progress")
	var readout := str(game._enemy_health_readout(lower_progress))
	_assert(readout.contains("68 / 120") and readout.contains("57%"), "hover chip should show current, maximum, and percentage")
	higher_progress["pos"] = Vector2(918, 105)
	var chip_rect := game._hover_health_chip_rect(higher_progress) as Rect2
	_assert(chip_rect.end.x <= game.HUD_PANEL_RECT.position.x - 12.0, "hover chip should remain clear of the right HUD")
	_assert(chip_rect.position.x >= game.MAP_RECT.position.x and chip_rect.position.y >= game.MAP_RECT.position.y, "hover chip should remain inside the gameplay map")
	var report := str(game._diagnostic_report_for_method(higher_progress, "read_registers"))
	_assert(report.contains("40 / 100") and report.contains("40%"), "diagnosis should include exact health for touch users")
	var root_source := FileAccess.get_file_as_string("res://scripts/band_defense_root.gd")
	_assert(!root_source.contains("Vector2(52 * hp_ratio, 5)"), "persistent enemy health bars should be removed")
	game.enemies.clear()
	game._clear_enemy_hit_feedback()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
