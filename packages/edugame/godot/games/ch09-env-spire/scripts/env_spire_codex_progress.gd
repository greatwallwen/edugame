extends RefCounted

const VERSION := 1


static func empty_progress() -> Dictionary:
	return {
		"version": VERSION,
		"cards": [] as Array[String],
		"faults": [] as Array[String]
	}


static func load_progress(
	path: String,
	valid_card_ids: Array[String],
	valid_fault_ids: Array[String]
) -> Dictionary:
	var progress := empty_progress()
	if path.is_empty():
		return progress
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return progress
	progress["cards"] = _normalized_ids(
		config.get_value("codex", "cards", PackedStringArray()),
		valid_card_ids
	)
	progress["faults"] = _normalized_ids(
		config.get_value("codex", "faults", PackedStringArray()),
		valid_fault_ids
	)
	return progress


static func save_progress(path: String, progress: Dictionary) -> bool:
	if path.is_empty():
		return false
	var config := ConfigFile.new()
	config.set_value("codex", "version", VERSION)
	config.set_value("codex", "cards", PackedStringArray(_normalized_ids(progress.get("cards", []))))
	config.set_value("codex", "faults", PackedStringArray(_normalized_ids(progress.get("faults", []))))
	return config.save(path) == OK


static func unlock(progress: Dictionary, kind: String, content_id: String) -> bool:
	if kind not in ["cards", "faults"] or content_id.is_empty():
		return false
	var ids := _normalized_ids(progress.get(kind, []))
	if ids.has(content_id):
		return false
	ids.append(content_id)
	ids.sort()
	progress[kind] = ids
	progress["version"] = VERSION
	return true


static func _normalized_ids(raw_ids: Variant, valid_ids: Array[String] = []) -> Array[String]:
	var normalized: Array[String] = []
	if typeof(raw_ids) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		return normalized
	for raw_id in raw_ids:
		var content_id := str(raw_id)
		if content_id.is_empty() or normalized.has(content_id):
			continue
		if !valid_ids.is_empty() and !valid_ids.has(content_id):
			continue
		normalized.append(content_id)
	normalized.sort()
	return normalized
