extends SceneTree

const SAVE_PATH := "user://ch09_run_save_test.json"
const SETTINGS_PATH := "user://ch09_settings_test.cfg"
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var persistence = load("res://scripts/env_spire_run_persistence.gd")
	var settings_store = load("res://scripts/env_spire_settings_store.gd")
	_cleanup()
	var catalogs := {
		"cards": {"a": {}},
		"negativeCards": {"bad": {}},
		"components": {"part": {}},
		"enemies": {"fault": {}}
	}
	var snapshot := {
		"state": 1,
		"runMap": {"id": "test"},
		"deck": [{"id": "a"}],
		"drawPile": [{"id": "a"}],
		"discardPile": [{"id": "bad", "negative": true}],
		"exhaustPile": [],
		"hand": [],
		"retainedCards": [],
		"relics": ["part"],
		"currentEncounter": {"id": "fault"}
	}
	_assert(bool(persistence.save(SAVE_PATH, snapshot).get("ok", false)), "run persistence should save a versioned snapshot")
	var loaded: Dictionary = persistence.load(SAVE_PATH, catalogs)
	var loaded_snapshot := loaded.get("snapshot", {}) as Dictionary
	_assert(bool(loaded.get("ok", false)) and int(loaded_snapshot.get("state", -1)) == 1 and (loaded_snapshot.get("deck", []) as Array).size() == 1, "run persistence should round-trip a valid snapshot")
	snapshot.deck = [{"id": "removed"}]
	_assert(bool(persistence.save(SAVE_PATH, snapshot).get("ok", false)), "invalid catalog fixture should write")
	_assert(!bool(persistence.load(SAVE_PATH, catalogs).get("ok", true)), "deleted content references should invalidate a save")
	_assert(bool(persistence.delete(SAVE_PATH).get("ok", false)) and !FileAccess.file_exists(SAVE_PATH), "run persistence should delete a save")

	var defaults: Dictionary = settings_store.defaults()
	_assert(defaults == {"sfxEnabled": true, "sfxVolume": 0.4, "animationSpeed": 1.0, "reducedFlash": false}, "settings should expose release defaults")
	var validated: Dictionary = settings_store.validate({"sfxVolume": 3.0, "animationSpeed": 2.0})
	_assert(is_equal_approx(float(validated.sfxVolume), 1.0) and is_equal_approx(float(validated.animationSpeed), 1.0), "settings should clamp volume and reject unsupported speed")
	var custom := {"sfxEnabled": false, "sfxVolume": 0.65, "animationSpeed": 1.5, "reducedFlash": true}
	_assert(settings_store.save(SETTINGS_PATH, custom), "settings should save through the store")
	_assert(settings_store.load(SETTINGS_PATH) == custom, "settings should persist across reload")
	_cleanup()
	if failures > 0:
		quit(1)
	else:
		print("Ch09 persistence and settings tests passed")
		quit(0)


func _cleanup() -> void:
	for path in [SAVE_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
