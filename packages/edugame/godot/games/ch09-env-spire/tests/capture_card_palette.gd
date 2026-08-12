extends SceneTree

const OUT_PATH_PROJECT_PATH := "res://../../../../../.superpowers/visual-qa/ch09-env-spire/70-desktop-card-palette.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var out_path := ProjectSettings.globalize_path(OUT_PATH_PROJECT_PATH)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	get_root().size = VIEWPORT_SIZE

	var stage := ColorRect.new()
	stage.color = Color("#11161b")
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(stage)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.position = Vector2(-470, -260)
	stage.add_child(row)

	var normal_cards := _cards_by_id(["mq2_sample", "bh1750_read"])
	var negative_cards := _negative_cards_by_id(["abnormal_reading", "i2c_nack"])
	var card_view_script = load("res://scripts/env_spire_card_view.gd")
	for card in normal_cards + negative_cards:
		var view = card_view_script.new()
		row.add_child(view)
		view.configure_card(card, "choice", int(card.get("cost", 0)), "", "")

	for _frame in range(4):
		await process_frame
	var image := get_root().get_texture().get_image()
	var result := image.save_png(out_path)
	if result != OK:
		push_error("Failed to save card palette capture: %s" % result)
		quit(1)
		return
	print("Saved card palette capture: %s" % out_path)
	quit(0)


func _cards_by_id(ids: Array[String]) -> Array[Dictionary]:
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.local.json")) as Dictionary
	return _select_cards(payload.get("cards", []) as Array, ids)


func _negative_cards_by_id(ids: Array[String]) -> Array[Dictionary]:
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.local.json")) as Dictionary
	return _select_cards(payload.get("negativeCards", []) as Array, ids)


func _select_cards(source: Array, ids: Array[String]) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for card in source:
		var card_data := card as Dictionary
		if str(card_data.get("id", "")) in ids:
			selected.append(card_data)
	return selected
