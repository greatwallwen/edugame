extends SceneTree

var failures := 0
var test_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var progress_store = load("res://scripts/env_spire_codex_progress.gd")
	_assert(progress_store != null, "codex progress helper should load independently")
	if progress_store == null:
		_finish()
		return

	var valid_cards: Array[String] = ["adc_convert", "mq2_sample"]
	var valid_faults: Array[String] = ["bh1750_stale", "mq2_warmup"]
	var missing_path := _test_path("missing")
	var empty := progress_store.load_progress(missing_path, valid_cards, valid_faults) as Dictionary
	_assert(int(empty.get("version", 0)) == 1, "missing progress should use current version")
	_assert((empty.get("cards", []) as Array).is_empty(), "missing progress should start with no cards")
	_assert((empty.get("faults", []) as Array).is_empty(), "missing progress should start with no faults")

	_assert(progress_store.unlock(empty, "cards", "mq2_sample"), "first card discovery should change progress")
	_assert(!progress_store.unlock(empty, "cards", "mq2_sample"), "duplicate card discovery should not change progress")
	_assert(progress_store.unlock(empty, "faults", "mq2_warmup"), "first fault discovery should change progress")
	_assert(!progress_store.unlock(empty, "unknown", "mq2_sample"), "unknown discovery kind should be rejected")
	_assert(progress_store.save_progress(missing_path, empty), "valid progress should save")
	var round_trip := progress_store.load_progress(missing_path, valid_cards, valid_faults) as Dictionary
	_assert(round_trip.get("cards", []) == ["mq2_sample"], "saved card discoveries should round trip")
	_assert(round_trip.get("faults", []) == ["mq2_warmup"], "saved fault discoveries should round trip")

	var filtered_path := _test_path("filtered")
	var config := ConfigFile.new()
	config.set_value("codex", "version", 1)
	config.set_value("codex", "cards", PackedStringArray(["mq2_sample", "unknown_card", "adc_convert", "mq2_sample"]))
	config.set_value("codex", "faults", PackedStringArray(["mq2_warmup", "unknown_fault", "bh1750_stale", "mq2_warmup"]))
	_assert(config.save(filtered_path) == OK, "test fixture should save")
	var filtered := progress_store.load_progress(filtered_path, valid_cards, valid_faults) as Dictionary
	_assert(filtered.get("cards", []) == ["adc_convert", "mq2_sample"], "card IDs should be valid, unique, and sorted")
	_assert(filtered.get("faults", []) == ["bh1750_stale", "mq2_warmup"], "fault IDs should be valid, unique, and sorted")

	var corrupt_path := _test_path("corrupt")
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	_assert(file != null, "corrupt fixture should open")
	if file != null:
		file.store_string("not a ConfigFile")
		file.close()
	var recovered := progress_store.load_progress(corrupt_path, valid_cards, valid_faults) as Dictionary
	_assert((recovered.get("cards", []) as Array).is_empty(), "corrupt progress should recover with no cards")
	_assert((recovered.get("faults", []) as Array).is_empty(), "corrupt progress should recover with no faults")

	_finish()


func _test_path(suffix: String) -> String:
	var path := "user://ch09_codex_test_%d_%s.cfg" % [Time.get_ticks_msec(), suffix]
	test_paths.append(path)
	return path


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	for path in test_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	if failures == 0:
		print("Ch09 codex progress tests passed")
	quit(1 if failures > 0 else 0)
