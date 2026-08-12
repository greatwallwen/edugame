extends RefCounted
class_name DGBKnowledgeProvider


static func resolve(data: Dictionary, fallbacks: Dictionary, local_preview := false) -> Dictionary:
	var external := false
	var questions := _array_value(data, "questions")
	var upgrades := _array_value(data, "upgrades")
	var concepts := _array_value(data, "concepts")
	var bindings = data.get("bindings", null)
	if data.has("questions") and typeof(data.get("questions")) == TYPE_ARRAY:
		external = true
	if data.has("upgrades") and typeof(data.get("upgrades")) == TYPE_ARRAY:
		external = true
	if data.has("concepts") and typeof(data.get("concepts")) == TYPE_ARRAY:
		external = true
	if typeof(bindings) == TYPE_ARRAY or typeof(bindings) == TYPE_DICTIONARY:
		external = true
	else:
		bindings = {}

	if questions.is_empty():
		questions = _load_arrays(fallbacks.get("questions", ""))
	if upgrades.is_empty():
		upgrades = _load_arrays(fallbacks.get("upgrades", ""))
	if concepts.is_empty():
		concepts = _load_arrays(fallbacks.get("concepts", ""))
	if (bindings as Variant) is Dictionary and (bindings as Dictionary).is_empty():
		bindings = _load_bindings(str(fallbacks.get("bindings", "")))

	return {
		"questions": questions,
		"upgrades": upgrades,
		"bindings": bindings,
		"concepts": concepts,
		"source": "local_preview" if local_preview else ("external" if external else "embedded")
	}


static func _array_value(data: Dictionary, key: String) -> Array:
	var value = data.get(key, [])
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _load_array(path: String) -> Array:
	var value = _load_json(path)
	if typeof(value) == TYPE_ARRAY:
		return value as Array
	if path != "":
		push_warning("Expected JSON array at %s" % path)
	return []


static func _load_arrays(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return _load_array(str(value))
	var combined: Array = []
	for path in value as Array:
		combined.append_array(_load_array(str(path)))
	return combined


static func _load_bindings(path: String):
	var value = _load_json(path)
	if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
		return value
	if path != "":
		push_warning("Expected JSON array or dictionary at %s" % path)
	return {}


static func _load_json(path: String):
	if path == "":
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open knowledge fallback %s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_warning("Unable to parse knowledge fallback %s" % path)
	return parsed
