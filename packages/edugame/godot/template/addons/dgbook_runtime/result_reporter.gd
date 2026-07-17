extends RefCounted
class_name DGBResultReporter

var _bridge
var _initialized := false
var _completed := false


func _init(bridge = null) -> void:
	_bridge = bridge


func mark_initialized() -> void:
	_initialized = true


func report_progress(progress: float, hint := "", stats := {}) -> bool:
	if !_initialized or _completed or _bridge == null:
		_log_warning("Ignored progress outside an active session.")
		return false
	_bridge.send_progress(clampf(progress, 0.0, 1.0), hint, stats)
	return true


func complete(score: float, stars := -1, duration_ms := 0, stats := {}) -> bool:
	if !_initialized or _completed or _bridge == null:
		_log_warning("Ignored duplicate or inactive completion.")
		return false
	_completed = true
	var normalized_stars := clampi(int(stars), -1, 3)
	_bridge.send_complete(clampf(score, 0.0, 100.0), normalized_stars, maxi(int(duration_ms), 0), stats)
	return true


func reset() -> void:
	_initialized = false
	_completed = false


func is_completed() -> bool:
	return _completed


func _log_warning(message: String) -> void:
	if _bridge != null and _bridge.has_method("send_log"):
		_bridge.send_log(message, "warn")
