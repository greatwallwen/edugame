extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var codex_script = load("res://scripts/env_spire_codex_view.gd")
	_assert(codex_script != null, "codex view should load independently")
	if codex_script == null:
		_finish(null)
		return

	var card_defs := {
		"secret_card": {
			"id": "secret_card", "name": "机密卡名", "type": "process", "rarity": "rare",
			"stage": "process", "cost": 2, "effectText": "机密卡牌效果", "knowledgePoint": "机密卡牌知识"
		},
		"known_card": {
			"id": "known_card", "name": "已知卡牌", "type": "collect", "rarity": "common",
			"stage": "collect", "cost": 1, "effectText": "已知卡牌效果", "knowledgePoint": "已知卡牌知识"
		}
	}
	var fault_defs := {
		"secret_fault": {
			"id": "secret_fault", "name": "机密故障名", "tier": "elite", "region": 2,
			"knowledgePoint": "机密故障知识", "weaknessTags": ["secret_weakness"],
			"faultRule": {"description": "机密触发规则", "counterText": "机密反制答案"}
		},
		"known_fault": {
			"id": "known_fault", "name": "已知故障", "tier": "ordinary", "region": 1,
			"knowledgePoint": "已知故障知识", "weaknessTags": ["known_tag"],
			"faultRule": {"description": "已知触发规则", "counterText": "已知反制答案"}
		}
	}

	var locked_cards: Array = codex_script.build_entry_models(card_defs, ["known_card"], "cards")
	var serialized_locked := JSON.stringify(locked_cards)
	for secret in ["secret_card", "机密卡名", "机密卡牌效果", "机密卡牌知识"]:
		_assert(!serialized_locked.contains(secret), "locked card model must not expose %s" % secret)
	_assert(serialized_locked.contains("尚未记录"), "locked card model should expose only its placeholder")

	var locked_faults: Array = codex_script.build_entry_models(fault_defs, ["known_fault"], "faults")
	var serialized_faults := JSON.stringify(locked_faults)
	for secret in ["secret_fault", "机密故障名", "机密故障知识", "secret_weakness", "机密触发规则", "机密反制答案"]:
		_assert(!serialized_faults.contains(secret), "locked fault model must not expose %s" % secret)

	var view = codex_script.new()
	get_root().add_child(view)
	await process_frame
	var codex_surface := view.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(codex_surface.bg_color.get_luminance() > 0.82, "codex should use the shared light layout surface")
	var codex_frame := view.find_child("CodexTacticalFrame", true, false) as Control
	_assert(codex_frame != null and str(codex_frame.call("visual_signature")).contains("tactical_hud"), "codex should use the out-of-run tactical HUD frame")
	view.configure(card_defs, fault_defs, {"cards": ["known_card"], "faults": ["known_fault"]})
	var body := view.find_child("CodexDetailBody", true, false) as Label
	_assert(_font_path(body.get_theme_font("font")).ends_with("NotoSansSC-VF.ttf"), "codex card-detail paragraphs should retain Noto Sans SC")
	_assert(view.find_child("CodexTabCards", true, false) is Button, "codex should expose a card tab")
	_assert(view.find_child("CodexTabFaults", true, false) is Button, "codex should expose a fault tab")
	_assert(view.find_child("CodexBack", true, false) is Button, "codex should expose a menu return")
	var first_entry := view.find_child("CodexEntry0", true, false) as Button
	_assert(first_entry != null and (first_entry.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.get_luminance() < 0.20, "codex entry commands should remain dark on the light archive surface")
	_assert((view.find_child("CodexProgress", true, false) as Label).text.contains("1 / 2"), "card tab should show discovery progress")

	view.select_entry(1)
	var title := view.find_child("CodexDetailTitle", true, false) as Label
	body = view.find_child("CodexDetailBody", true, false) as Label
	var title_font := title.get_theme_font("font")
	_assert(title_font is FontVariation and int((title_font as FontVariation).variation_opentype.get("wght", 0)) >= 700, "codex detail title should use a bold variable weight")
	_assert(title.text == "尚未记录", "locked detail should hide its title")
	_assert(!body.text.contains("机密"), "locked detail should hide all secret copy")

	view.select_tab("faults")
	_assert((view.find_child("CodexProgress", true, false) as Label).text.contains("1 / 2"), "fault tab should show discovery progress")
	view.select_entry(0)
	title = view.find_child("CodexDetailTitle", true, false) as Label
	body = view.find_child("CodexDetailBody", true, false) as Label
	_assert(title.text == "已知故障", "unlocked fault should reveal its title")
	_assert(body.text.contains("已知反制答案"), "unlocked fault should reveal its countermeasure")
	_assert(_font_path(body.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "codex fault details should follow the global DingTalk art font")

	var close_state := {"emitted": false}
	view.close_requested.connect(func() -> void: close_state["emitted"] = true)
	(view.find_child("CodexBack", true, false) as Button).pressed.emit()
	_assert(bool(close_state.get("emitted", false)), "codex return should emit its close command")
	_finish(view)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _font_path(font: Font) -> String:
	var resolved := (font as FontVariation).base_font if font is FontVariation else font
	return resolved.resource_path if resolved != null else ""


func _finish(view) -> void:
	if is_instance_valid(view):
		view.queue_free()
	if failures == 0:
		print("Ch09 codex view tests passed")
	quit(1 if failures > 0 else 0)
