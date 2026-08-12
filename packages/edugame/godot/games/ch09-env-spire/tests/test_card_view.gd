extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card_view_script = load("res://scripts/env_spire_card_view.gd")
	_assert(card_view_script != null, "production card view script should load")
	_assert(card_view_script != null and card_view_script.can_instantiate(), "production card view script should instantiate")
	if card_view_script == null or !card_view_script.can_instantiate():
		_finish()
		return

	var known_card := {
		"id": "mq2_sample",
		"name": "MQ-2 采样",
		"type": "collect",
		"rarity": "starter",
		"cost": 1,
		"effectText": "获得 1 个烟雾原始数据，修复 4。",
		"knowledgePoint": "MQ-2 AO 为模拟输出，需要 ADC 采样。"
	}
	var hand_view = card_view_script.new()
	get_root().add_child(hand_view)
	hand_view.configure_card(known_card, "hand", 1, "", "连携推进")
	await process_frame

	_assert(hand_view is Button, "production card should preserve button semantics")
	_assert(hand_view.custom_minimum_size.y > hand_view.custom_minimum_size.x, "hand cards should be portrait")
	_assert(hand_view.get_node_or_null("CardCostOrb") != null, "card should expose a stable cost-orb node")
	_assert(hand_view.get_node_or_null("CardTitle") != null, "card should expose a stable title node")
	_assert(hand_view.get_node_or_null("CardArt") != null, "card should expose a stable artwork node")
	_assert(hand_view.get_node_or_null("CardTypeStrip") != null, "card should expose a stable type-strip node")
	_assert(hand_view.get_node_or_null("CardEffect") != null, "card should expose a stable effect node")
	_assert(hand_view.get_node_or_null("CardFooter") != null, "card should expose a stable footer node")
	_assert(hand_view.get_node_or_null("CardUnavailableOverlay") != null, "card should expose a stable unavailable-state node")
	_assert((hand_view.get_node("CardTitle") as Label).get_theme_font_size("font_size") >= 12, "hand-card titles should remain readable at desktop distance")
	_assert((hand_view.get_node("CardTitle") as Label).has_theme_color_override("font_color") and (hand_view.get_node("CardTitle") as Label).get_theme_color("font_color").get_luminance() > 0.82, "card titles should explicitly keep light text on their dark category header")
	_assert((hand_view.get_node("CardEffect") as Label).get_theme_font_size("font_size") >= 10, "hand-card rules text should remain readable at desktop distance")
	_assert((hand_view.get_node("CardFooter") as Label).get_theme_font_size("font_size") >= 8, "hand-card support text should remain readable at desktop distance")
	var card_title_label := hand_view.find_child("CardTitle", true, false) as Label
	var card_cost_label := hand_view.find_child("CardCost", true, false) as Label
	var card_effect_label := hand_view.find_child("CardEffect", true, false) as Label
	var unavailable_label := hand_view.find_child("CardUnavailableReason", true, false) as Label
	_assert(card_title_label.has_theme_font_override("font"), "card titles should explicitly bind the shared Ch11 art font")
	_assert(card_cost_label.has_theme_font_override("font"), "card costs should explicitly bind the shared Ch11 art font")
	_assert(card_effect_label.has_theme_font_override("font"), "card effect details should explicitly bind the readable font exception")
	_assert(unavailable_label.has_theme_font_override("font"), "card unavailable details should explicitly bind the readable font exception")
	if card_title_label.has_theme_font_override("font"):
		_assert(_font_path(card_title_label.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "card titles should use the shared Ch11 art font")
	if card_cost_label.has_theme_font_override("font"):
		_assert(_font_path(card_cost_label.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "card costs should use the shared Ch11 art font")
	if card_effect_label.has_theme_font_override("font"):
		_assert(_font_path(card_effect_label.get_theme_font("font")).ends_with("NotoSansSC-VF.ttf"), "card effect details should keep the readable Noto Sans SC exception")
	if unavailable_label.has_theme_font_override("font"):
		_assert(_font_path(unavailable_label.get_theme_font("font")).ends_with("NotoSansSC-VF.ttf"), "card unavailable details should keep the readable Noto Sans SC exception")

	var cost_orb := hand_view.get_node_or_null("CardCostOrb") as Control
	var card_title := hand_view.get_node_or_null("CardTitle") as Control
	var art := hand_view.get_node_or_null("CardArt") as TextureRect
	var fallback := hand_view.get_node_or_null("CardArtFallback") as Control
	_assert(cost_orb != null and cost_orb.position.x < 0.0, "cost orb should protrude beyond the upper-left frame")
	_assert(
		cost_orb != null and card_title != null
		and !Rect2(cost_orb.position, cost_orb.size).intersects(Rect2(card_title.position, card_title.size)),
		"cost orb should not overlap the card title"
	)
	_assert(art != null and art.texture != null and art.visible, "known cards should load approved artwork")
	_assert(fallback != null and !fallback.visible, "known card artwork should hide the fallback")
	_assert(hand_view.tooltip_text == str(known_card.get("knowledgePoint", "")), "card tooltip should expose its knowledge point")
	_assert(str(hand_view.get_node("CardTitle").text) == "MQ-2 采样", "card title should use localized data")
	_assert(str(hand_view.get_node("CardEffect").text).contains("修复 4"), "card effect should use gameplay data")

	_assert(hand_view.has_method("has_card_art"), "production card view should expose card-art coverage checks")
	if hand_view.has_method("has_card_art"):
		var cards_payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.local.json")) as Dictionary
		for card in cards_payload.get("cards", []) as Array:
			var card_id := str((card as Dictionary).get("id", ""))
			_assert(hand_view.has_card_art(card_id), "normal card should have approved artwork: %s" % card_id)

		var enemies_payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.local.json")) as Dictionary
		for negative_card in enemies_payload.get("negativeCards", []) as Array:
			var negative_id := str((negative_card as Dictionary).get("id", ""))
			_assert(hand_view.has_card_art(negative_id), "negative card should have approved artwork: %s" % negative_id)

	var fallback_card := {
		"id": "future_card",
		"name": "未来卡牌",
		"type": "process",
		"rarity": "common",
		"cost": 2,
		"effectText": "获得 5 防护。",
		"knowledgePoint": "测试回退卡图。"
	}
	var choice_view = card_view_script.new()
	get_root().add_child(choice_view)
	choice_view.configure_card(fallback_card, "choice", 2, "缺少原始数据", "普通 · 处理")
	await process_frame

	var choice_art := choice_view.get_node_or_null("CardArt") as TextureRect
	var choice_fallback := choice_view.get_node_or_null("CardArtFallback") as Control
	var unavailable := choice_view.get_node_or_null("CardUnavailableOverlay") as Control
	var choice_cost := choice_view.get_node_or_null("CardCostOrb") as Control
	var choice_title := choice_view.get_node_or_null("CardTitle") as Control
	_assert(choice_view.custom_minimum_size.y > choice_view.custom_minimum_size.x, "choice cards should be portrait")
	_assert(
		choice_cost != null and choice_title != null
		and !Rect2(choice_cost.position, choice_cost.size).intersects(Rect2(choice_title.position, choice_title.size)),
		"choice-card cost orb should not overlap the card title"
	)
	_assert(choice_art != null and !choice_art.visible, "unknown cards should not expose an empty texture")
	_assert(choice_fallback != null and choice_fallback.visible, "unknown cards should expose the type-colored fallback")
	_assert(unavailable != null and unavailable.visible, "unavailable cards should expose a visible overlay")
	_assert(choice_view.disabled, "unavailable cards should preserve disabled button semantics")

	var compact_view = card_view_script.new()
	get_root().add_child(compact_view)
	compact_view.configure_card(known_card, "compact", 1, "", "协同")
	await process_frame
	var compact_cost := compact_view.get_node_or_null("CardCostOrb") as Control
	var compact_title := compact_view.get_node_or_null("CardTitle") as Control
	_assert(compact_view.custom_minimum_size == Vector2(166, 240), "compact cards should use the desktop reward footprint")
	_assert(
		compact_cost != null and compact_title != null
		and !Rect2(compact_cost.position, compact_cost.size).intersects(Rect2(compact_title.position, compact_title.size)),
		"compact-card cost orb should not overlap the card title"
	)

	hand_view.queue_free()
	choice_view.queue_free()
	compact_view.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _font_path(font: Font) -> String:
	var resolved := (font as FontVariation).base_font if font is FontVariation else font
	return resolved.resource_path if resolved != null else ""


func _finish() -> void:
	if failures == 0:
		print("Ch09 card view tests passed")
	quit(1 if failures > 0 else 0)
