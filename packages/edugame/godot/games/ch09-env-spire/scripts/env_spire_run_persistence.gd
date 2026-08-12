extends RefCounted

const VERSION := 3


static func save(path: String, snapshot: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed"}
	file.store_string(JSON.stringify({"version": VERSION, "snapshot": snapshot}))
	file.close()
	return {"ok": true}


static func load(path: String, catalogs: Dictionary) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {"ok": false, "error": "missing"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "invalid_json"}
	var parsed = parser.data
	if !(parsed is Dictionary):
		return {"ok": false, "error": "invalid_json"}
	var envelope := parsed as Dictionary
	if int(envelope.get("version", -1)) != VERSION:
		return {"ok": false, "error": "version"}
	var snapshot = envelope.get("snapshot")
	if !(snapshot is Dictionary) or !_valid_snapshot(snapshot as Dictionary, catalogs):
		return {"ok": false, "error": "catalog"}
	return {"ok": true, "snapshot": (snapshot as Dictionary).duplicate(true)}


static func delete(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {"ok": true}
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"ok": error == OK, "error": "delete_failed" if error != OK else ""}


static func _valid_snapshot(snapshot: Dictionary, catalogs: Dictionary) -> bool:
	if !snapshot.has("runMap") or !snapshot.has("state") or !snapshot.has("deck"):
		return false
	var cards := catalogs.get("cards", {}) as Dictionary
	var negatives := catalogs.get("negativeCards", {}) as Dictionary
	for pile_name in ["deck", "drawPile", "discardPile", "exhaustPile", "hand", "retainedCards"]:
		for raw_card in snapshot.get(pile_name, []) as Array:
			var card := raw_card as Dictionary
			var card_id := str(card.get("id", ""))
			if !cards.has(card_id) and !negatives.has(card_id):
				return false
	var components := catalogs.get("components", {}) as Dictionary
	for component_id in snapshot.get("relics", []) as Array:
		if !components.has(str(component_id)):
			return false
	var encounter_id := str((snapshot.get("currentEncounter", {}) as Dictionary).get("id", ""))
	if !encounter_id.is_empty() and !["sensor_checkpoint", "trust_checkpoint"].has(encounter_id):
		if !(catalogs.get("enemies", {}) as Dictionary).has(encounter_id):
			return false
	return true
