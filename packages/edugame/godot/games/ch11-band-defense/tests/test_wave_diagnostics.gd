extends SceneTree

var failures := 0


func _init() -> void:
	_test_summary_reports_strong_and_weak_points()
	_test_empty_wave_summary_is_clear()
	_test_level_summary_reports_match_rate_and_weak_module()
	_test_wave_summary_names_focus_and_next_action()
	if failures > 0:
		quit(1)
	else:
		print("wave diagnostics tests passed")
		quit(0)


func _test_summary_reports_strong_and_weak_points() -> void:
	var diagnostics_script = load("res://scripts/wave_diagnostics.gd")
	_assert(diagnostics_script != null, "wave_diagnostics.gd should load")
	if diagnostics_script == null:
		return
	var result: String = diagnostics_script.build_wave_summary({
		"wave": 2,
		"matched_hits": {"noise": 4, "false_peak": 1},
		"mismatched_hits": {"false_peak": 3},
		"kills": {"noise": 2},
		"leaks": {"false_peak": 1}
	}, {
		"noise": {"label": "噪声包"},
		"false_peak": {"label": "假峰值"}
	})
	_assert(result.contains("第 2 波诊断"), "summary should include wave number")
	_assert(result.contains("拦截稳定：噪声包"), "summary should name strongest handled concept")
	_assert(result.contains("优先复习：假峰值"), "summary should name weakest concept")
	_assert(result.contains("错配命中 3 次"), "summary should include mismatch count")


func _test_empty_wave_summary_is_clear() -> void:
	var diagnostics_script = load("res://scripts/wave_diagnostics.gd")
	_assert(diagnostics_script != null, "wave_diagnostics.gd should load")
	if diagnostics_script == null:
		return
	var result: String = diagnostics_script.build_wave_summary({"wave": 1}, {})
	_assert(result.contains("还没有形成有效诊断"), "empty stats should have a clear fallback")


func _test_level_summary_reports_match_rate_and_weak_module() -> void:
	var diagnostics_script = load("res://scripts/wave_diagnostics.gd")
	_assert(diagnostics_script != null, "wave_diagnostics.gd should load")
	if diagnostics_script == null:
		return
	var has_level_summary := false
	for method in diagnostics_script.get_script_method_list():
		if str((method as Dictionary).get("name", "")) == "build_level_summary":
			has_level_summary = true
			break
	_assert(has_level_summary, "wave_diagnostics.gd should expose build_level_summary")
	if !has_level_summary:
		return
	var result: String = diagnostics_script.build_level_summary({
		"level": 2,
		"matched_hits": {"noise": 8, "false_peak": 2},
		"mismatched_hits": {"false_peak": 5},
		"kills": {"noise": 4, "false_peak": 1},
		"leaks": {"false_peak": 2}
	}, {
		"noise": {"label": "噪声包"},
		"false_peak": {"label": "假峰值"}
	})
	_assert(result.contains("第 2 关诊断"), "level summary should include level number")
	_assert(result.contains("匹配率：67%"), "level summary should include rounded match rate")
	_assert(result.contains("主要薄弱点：假峰值"), "level summary should report weakest module")


func _test_wave_summary_names_focus_and_next_action() -> void:
	var diagnostics_script = load("res://scripts/wave_diagnostics.gd")
	_assert(diagnostics_script != null, "wave_diagnostics.gd should load")
	if diagnostics_script == null:
		return
	var result: String = diagnostics_script.build_wave_summary({
		"level": 3,
		"wave": 2,
		"focusType": "power_spike",
		"matched_hits": {"noise": 2},
		"mismatched_hits": {"power_spike": 5},
		"kills": {"noise": 1},
		"leaks": {"power_spike": 2}
	}, {
		"noise": {"label": "噪声包"},
		"power_spike": {"label": "功耗尖峰"}
	})
	_assert(result.contains("本波重点：功耗尖峰"), "summary should name the wave focus type")
	_assert(result.contains("下一步："), "summary should give a concrete next action")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
