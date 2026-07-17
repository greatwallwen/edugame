extends SceneTree

var failures := 0


class FakeBridge:
	extends RefCounted
	var progress_calls: Array = []
	var complete_calls: Array = []
	var logs: Array = []

	func send_progress(progress: float, hint := "", stats := {}) -> void:
		progress_calls.append({"progress": progress, "hint": hint, "stats": stats})

	func send_complete(score: float, stars := -1, duration_ms := 0, stats := {}) -> void:
		complete_calls.append({"score": score, "stars": stars, "duration_ms": duration_ms, "stats": stats})

	func send_log(message: String, level := "info") -> void:
		logs.append({"message": message, "level": level})


func _init() -> void:
	_test_protocol()
	_test_knowledge_priority_and_fallback()
	_test_session_config()
	_test_bridge_omits_unspecified_stars()
	_test_result_reporter()
	_test_runtime_does_not_begin_without_session()
	if failures > 0:
		quit(1)
	else:
		print("runtime primitive tests passed")
		quit(0)


func _test_protocol() -> void:
	var protocol = load("res://addons/dgbook_runtime/protocol.gd")
	_assert(protocol != null, "protocol script should load")
	if protocol == null:
		return
	_assert(protocol.VERSION == 1, "protocol version should remain v1")
	_assert(protocol.is_supported_version(null), "missing version should remain v1-compatible")
	_assert(protocol.is_supported_version(1), "version 1 should be supported")
	_assert(protocol.is_supported_version(1.0), "JSON-decoded version 1.0 should be supported")
	_assert(!protocol.is_supported_version(1.5), "fractional versions should be rejected")
	_assert(!protocol.is_supported_version(2), "version 2 should be rejected")


func _test_knowledge_priority_and_fallback() -> void:
	var provider = load("res://addons/dgbook_runtime/knowledge_provider.gd")
	_assert(provider != null, "knowledge provider should load")
	if provider == null:
		return
	var fallback_path := "user://runtime-test-questions.json"
	var file := FileAccess.open(fallback_path, FileAccess.WRITE)
	file.store_string('[{"id":"fallback"}]')
	file.close()
	var external = provider.resolve(
		{"questions": [{"id": "external"}], "bindings": {"mode": "course"}},
		{"questions": fallback_path},
		false
	)
	_assert(external.questions[0].id == "external", "external questions should win")
	_assert(external.bindings.mode == "course", "external bindings should be preserved")
	_assert(external.source == "external", "external data should report its source")
	var embedded = provider.resolve({}, {"questions": fallback_path}, false)
	_assert(embedded.questions[0].id == "fallback", "fallback questions should load")
	_assert(embedded.source == "embedded", "fallback data should report embedded source")
	var second_path := "user://runtime-test-questions-2.json"
	var second_file := FileAccess.open(second_path, FileAccess.WRITE)
	second_file.store_string('[{"id":"fallback-2"}]')
	second_file.close()
	var combined = provider.resolve({}, {"questions": [fallback_path, second_path]}, false)
	_assert(combined.questions.size() == 2, "multiple fallback files should concatenate")
	var local = provider.resolve({}, {"questions": fallback_path}, true)
	_assert(local.source == "local_preview", "local preview should report its source")


func _test_session_config() -> void:
	var config = load("res://addons/dgbook_runtime/session_config.gd")
	_assert(config != null, "session config should load")
	if config == null:
		return
	var result = config.build(
		{"levelId": "level-1"},
		{"durationSec": 90, "maxFaults": 3, "initialState": {"seed": 7}},
		{"duration_sec": 180.0, "max_faults": 5, "question_time_sec": 15.0}
	)
	_assert(result.duration_sec == 90.0, "host duration should override defaults")
	_assert(result.max_faults == 3, "host failure limit should override defaults")
	_assert(result.question_time_sec == 15.0, "missing host values should keep defaults")
	_assert(result.initial_state.seed == 7, "initial state should be preserved")
	_assert(result.level_id == "level-1", "level id should be normalized")


func _test_result_reporter() -> void:
	var reporter_script = load("res://addons/dgbook_runtime/result_reporter.gd")
	_assert(reporter_script != null, "result reporter should load")
	if reporter_script == null:
		return
	var bridge := FakeBridge.new()
	var reporter = reporter_script.new(bridge)
	_assert(!reporter.report_progress(0.5, "early", {}), "progress before init should be rejected")
	reporter.mark_initialized()
	_assert(reporter.report_progress(2.0, "running", {"wave": 1}), "initialized progress should send")
	_assert(bridge.progress_calls[0].progress == 1.0, "progress should clamp to one")
	_assert(reporter.complete(120.0, 3, -10, {"done": 1}), "first completion should send")
	_assert(!reporter.complete(80.0, 2, 10, {}), "second completion should be ignored")
	_assert(bridge.complete_calls.size() == 1, "bridge should receive one completion")
	_assert(bridge.complete_calls[0].score == 100.0, "score should clamp to one hundred")
	_assert(bridge.complete_calls[0].duration_ms == 0, "duration should clamp to zero")
	reporter.reset()
	reporter.mark_initialized()
	_assert(reporter.complete(50.0, 1, 10, {}), "reset should unlock completion")


func _test_bridge_omits_unspecified_stars() -> void:
	var bridge_script = load("res://addons/dgbook_runtime/bridge.gd")
	_assert(bridge_script != null, "bridge script should load")
	if bridge_script == null:
		return
	var bridge = bridge_script.new()
	var payloads: Array = []
	bridge.outbound_payload.connect(func(payload: Dictionary) -> void: payloads.append(payload))
	bridge.send_complete(80.0)
	_assert(payloads.size() == 1, "completion should emit one outbound payload")
	if payloads.size() == 1:
		_assert(!payloads[0].has("stars"), "unspecified stars should be omitted for host derivation")
	bridge.free()


func _test_runtime_does_not_begin_without_session() -> void:
	var runtime_script = load("res://addons/dgbook_runtime/runtime.gd")
	_assert(runtime_script != null, "runtime script should load")
	if runtime_script == null:
		return
	var runtime = runtime_script.new()
	_assert(!bool(runtime.call("begin_attempt")), "begin_attempt should reject an empty session")
	runtime.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
