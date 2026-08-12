extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route = load("res://scripts/env_spire_route_presenter.gd")
	var map_energy = load("res://scripts/env_spire_map_energy.gd")
	var choices = load("res://scripts/env_spire_choice_presenter.gd")
	var tutorial = load("res://scripts/env_spire_tutorial_presenter.gd")
	var feedback = load("res://scripts/env_spire_feedback_presenter.gd")
	_assert(route != null and route.can_instantiate(), "route presenter should load independently")
	_assert(map_energy != null and map_energy.can_instantiate(), "map energy renderer should load independently")
	_assert(choices != null and choices.can_instantiate(), "choice presenter should load independently")
	_assert(tutorial != null and tutorial.can_instantiate(), "tutorial presenter should load independently")
	_assert(feedback != null and feedback.can_instantiate(), "feedback presenter should load independently")
	if route == null or map_energy == null or choices == null or tutorial == null or feedback == null:
		_finish()
		return

	_assert(route.node_state(1, 0) == "available", "route presenter should identify the next node")
	_assert(route.node_state(1, 1) == "completed", "route presenter should identify completed nodes")
	_assert(route.progress_sequence(4, 12) == [1, 2, 3, 4], "route progress animation should travel from the bottom toward the selected node")
	_assert(is_equal_approx(float(map_energy.layer_progress(3, 12)), 0.25), "map energy renderer should convert cleared floors into a bottom-up charge ratio")
	_assert(is_equal_approx(float(map_energy.layer_progress(12, 12)), 1.0), "map energy renderer should fully charge the tower after the final floor")
	var hidden_spec := route.marker_spec(3, "future", "ordinary", false, "Hidden", "Ordinary") as Dictionary
	_assert(str(hidden_spec.get("stateText", "")).contains("待侦察"), "route presenter should expose a non-color future state")
	_assert(!str(hidden_spec.get("detailText", "")).contains("Hidden"), "route presenter should conceal unrevealed labels")
	_assert((hidden_spec.get("background", Color.BLACK) as Color).get_luminance() > 0.62, "future route nodes should use a quiet light signal surface")
	_assert((hidden_spec.get("textColor", Color.WHITE) as Color).get_luminance() < 0.55, "future route copy should remain subdued on the light rail surface")
	var available_spec := route.marker_spec(1, "available", "ordinary", true, "Active", "Ordinary") as Dictionary
	_assert(str(available_spec.get("nodeText", "")) == "01", "route node should reserve its control face for the node number")
	_assert(str(available_spec.get("detailText", "")).contains("Active"), "active route detail should sit beside the node control")
	_assert((available_spec.get("textColor", Color.BLACK) as Color).get_luminance() > 0.55, "active route number should remain legible on the dark surface")

	_assert(choices.columns_for("service") == 2, "choice presenter should keep service actions in two columns")
	_assert(choices.columns_for("component") == 3, "choice presenter should keep three component candidates on one desktop row")
	_assert(choices.card_mode_for("reward") == "choice", "rewards should use complete inspection cards")
	_assert(choices.card_mode_for("selection") == "choice", "choice presenter should preserve large inspection cards")

	var briefing_steps := tutorial.briefing_steps() as Array
	_assert(briefing_steps.size() == 4, "tutorial presenter should expose four briefing stages")
	_assert(!tutorial.coach_text(1).is_empty() and tutorial.expected_card_id(3) == "sliding_average", "tutorial presenter should own guided-step copy and targets")

	var cue_signatures := {}
	var audio_signatures := {}
	var cues := ["card", "chain", "repair", "weakness", "damage", "suppressed", "fault", "boss_1", "boss_2", "boss_3", "reward"]
	for cue in cues:
		var profile := feedback.cue_profile(cue) as Dictionary
		_assert(!(profile.get("notes", []) as Array).is_empty(), "feedback cue %s should contain notes" % cue)
		_assert(["sine", "triangle", "square", "noise"].has(str(profile.get("waveform", ""))), "feedback cue %s should define a supported waveform" % cue)
		_assert(float(profile.get("gain", 0.0)) > 0.0 and float(profile.get("gain", 0.0)) <= 1.0, "feedback cue %s should define a safe gain" % cue)
		cue_signatures[JSON.stringify(profile)] = true
		var stream := feedback.tone_sequence(profile) as AudioStreamWAV
		_assert(stream != null and !stream.data.is_empty(), "feedback cue %s should synthesize playable audio" % cue)
		if stream != null:
			audio_signatures[hash(stream.data)] = true
	_assert(cue_signatures.size() == cues.size(), "feedback presenter should keep all cue profiles distinct")
	_assert(audio_signatures.size() == cues.size(), "feedback presenter should synthesize audibly distinct cue data")
	_assert(feedback.target_key("repair", {}) == "evidence", "repair feedback should target evidence")
	_assert(feedback.target_key("weakness", {}) == "fault", "weakness feedback should target the fault core")
	_assert(feedback.target_key("fault_triggered", {}) == "fault", "fault feedback should target the fault core")

	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 presentation module tests passed")
	quit(1 if failures > 0 else 0)
