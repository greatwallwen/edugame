extends SceneTree

const CODEX_PATH := "user://ch09_learning_codex_test.cfg"
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var game = load("res://scenes/main.tscn").instantiate()
	game.codex_record_path = CODEX_PATH
	get_root().add_child(game)
	await process_frame
	game._reset_run()
	game._observe_knowledge(["mq2"], true)
	game._observe_knowledge(["mq2"], true)
	game._observe_knowledge(["i2c"], true)
	game._observe_knowledge(["adc"], false, "adc_spike")
	game.knowledge_stats.questionCorrect = 3
	game.knowledge_stats.questionTotal = 4
	game.knowledge_stats.weaknessRepair = 30
	game.knowledge_stats.totalRepair = 50
	var stats: Dictionary = game._run_stats()
	_assert((stats.get("masteredKnowledgeTags", []) as Array).has("mq2"), "host stats should include mastered tags")
	_assert((stats.get("reviewKnowledgeTags", []) as Array).has("adc"), "host stats should include review tags")
	_assert(is_equal_approx(float(stats.get("questionAccuracy", 0.0)), 0.75), "host stats should include question accuracy")
	_assert(is_equal_approx(float(stats.get("engineeringResolutionRate", 0.0)), 0.6), "host stats should include engineering resolution rate")

	game.codex_progress = {"version": 1, "cards": [], "faults": ["adc_spike"]}
	game.completed = true
	game.victory = false
	game.state = game.RunState.RESULT
	game._render_state()
	var summary := game.find_child("RunLearningSummary", true, false) as Label
	var review_button := game.find_child("ResultReviewButton", true, false) as Button
	_assert(summary != null and summary.text.contains("已掌握") and summary.text.contains("继续加强") and summary.text.contains("答题正确率 75%"), "result should render the knowledge report")
	_assert(summary != null and summary.text.contains("MQ-2 预热与校准") and summary.text.contains("ADC 转换") and !summary.text.contains("已掌握：mq2"), "result should present learner-facing knowledge names while host stats retain stable tags")
	_assert(review_button != null and review_button.visible, "result should expose an unlocked recommended fault")
	if review_button != null:
		review_button.pressed.emit()
		_assert(game.state == game.RunState.CODEX and game.codex_view.active_tab == "faults", "review action should open the fault codex")
		var model := game.codex_view.entry_models[game.codex_view.selected_index] as Dictionary
		_assert(str(model.get("id", "")) == "adc_spike", "review action should select the first recommended fault")

	game.queue_free()
	await process_frame
	_cleanup()
	if failures > 0:
		quit(1)
	else:
		print("Ch09 learning report tests passed")
		quit(0)


func _cleanup() -> void:
	if FileAccess.file_exists(CODEX_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CODEX_PATH))


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
