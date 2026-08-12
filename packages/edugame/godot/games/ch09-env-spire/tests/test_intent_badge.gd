extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var badge_script = load("res://scripts/env_spire_intent_badge.gd")
	_assert(badge_script != null, "intent badge script should load")
	if badge_script == null:
		_finish()
		return
	var badge = badge_script.new()
	get_root().add_child(badge)
	_assert(badge is Button, "intent badge should preserve clickable button semantics")
	_assert(badge.has_method("summary_for_intent"), "intent badge should expose deterministic intent summaries")
	_assert(badge.has_method("configure_intent"), "intent badge should expose intent binding")
	_assert(badge.has_method("visual_contract"), "intent badge should expose its compact layout contract")

	if badge.has_method("summary_for_intent"):
		var damage := badge.summary_for_intent({"type": "damage", "amount": 8, "text": "噪声冲击：稳定度 -8"}) as Dictionary
		_assert(damage.get("icon", "") == "damage", "damage intent should use the impact icon")
		_assert(damage.get("label", "") == "稳定度", "damage intent should use a concise stability label")
		_assert(damage.get("value", "") == "-8", "damage intent should emphasize its exact value")
		_assert(damage.get("tooltip", "") == "噪声冲击：稳定度 -8", "damage tooltip should preserve the full source text")

		var negative := badge.summary_for_intent({"type": "negative", "card": "stale_data", "text": "加入旧数据"}) as Dictionary
		_assert(negative.get("icon", "") == "negative", "negative-card intent should use the card-plus icon")
		_assert(negative.get("label", "") == "旧数据", "negative-card intent should remove the redundant action prefix")
		_assert(negative.get("value", "") == "+1", "negative-card intent should expose the number of cards added")

		var fallback := badge.summary_for_intent({"type": "future", "text": "执行系统检查"}) as Dictionary
		_assert(fallback.get("icon", "") == "warning", "unknown intent should use the warning icon")
		_assert(fallback.get("label", "") == "系统检查", "unknown intent should keep a concise meaningful label")

	if badge.has_method("configure_intent"):
		badge.configure_intent({"type": "damage", "amount": 8, "text": "噪声冲击：稳定度 -8"}, null)
		_assert(badge.tooltip_text == "噪声冲击：稳定度 -8", "bound badge should expose the complete intent on hover")
		_assert(badge.custom_minimum_size == Vector2(154, 42), "intent badge should use the approved compact footprint")
		_assert(badge.focus_mode == Control.FOCUS_ALL and badge.mouse_filter == Control.MOUSE_FILTER_STOP, "intent badge should remain keyboard and pointer actionable")

	if badge.has_method("visual_contract"):
		var contract := badge.visual_contract() as Dictionary
		_assert(contract.get("iconSize", 0) >= 24, "intent icon should remain readable at desktop distance")
		_assert(contract.get("maxLines", 9) == 1, "intent badge should remain a single-line scan target")

	badge.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 intent badge tests passed")
	quit(1 if failures > 0 else 0)
