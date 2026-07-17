extends SceneTree

var failures := 0


func _init() -> void:
	_test_question_bank_is_deeper_and_valid()
	if failures > 0:
		quit(1)
	else:
		print("question bank depth tests passed")
		quit(0)


func _test_question_bank_is_deeper_and_valid() -> void:
	var questions := []
	for path in ["res://data/questions.local.json"]:
		var parsed = _read_json(path)
		_assert(typeof(parsed) == TYPE_ARRAY, "%s should contain an array" % path)
		if typeof(parsed) == TYPE_ARRAY:
			questions.append_array(parsed)
	_assert(questions.size() >= 30, "question bank should have at least 30 questions")
	var ids := {}
	var level_counts := {1: 0, 2: 0, 3: 0}
	var modules := {}
	for raw_question in questions:
		var question := raw_question as Dictionary
		var id := str(question.get("id", ""))
		_assert(id != "", "question should have id")
		_assert(!ids.has(id), "question id should be unique: %s" % id)
		ids[id] = true
		var level := int(question.get("level", 1))
		level_counts[level] = int(level_counts.get(level, 0)) + 1
		modules[str(question.get("module", ""))] = true
		var choices := question.get("choices", []) as Array
		_assert(str(question.get("prompt", "")) != "", "%s should have prompt" % id)
		_assert(choices.size() == 4, "%s should have four choices" % id)
		var answer_index := int(question.get("answerIndex", -1))
		_assert(answer_index >= 0 and answer_index < choices.size(), "%s should have valid answerIndex" % id)
		_assert(str(question.get("explanation", "")) != "", "%s should have explanation" % id)
		_assert(str(question.get("unlockTag", "")) != "", "%s should have unlockTag" % id)
	_assert(int(level_counts[1]) >= 12, "level 1 should have at least 12 questions")
	_assert(int(level_counts[2]) >= 9, "level 2 should have at least 9 questions")
	_assert(int(level_counts[3]) >= 9, "level 3 should have at least 9 questions")
	for module in ["i2c", "filter", "step", "power", "mixed"]:
		_assert(modules.has(module), "question bank should cover module: %s" % module)


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
