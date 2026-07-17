extends RefCounted
class_name DGBProtocol

const VERSION := 1
const READY := "DGB_GODOT_READY"
const INIT := "DGB_GODOT_INIT"
const PAUSE := "DGB_GODOT_PAUSE"
const RESUME := "DGB_GODOT_RESUME"
const RESET := "DGB_GODOT_RESET"
const PROGRESS := "DGB_GODOT_PROGRESS"
const COMPLETE := "DGB_GODOT_COMPLETE"
const LOG := "DGB_GODOT_LOG"


static func is_supported_version(value) -> bool:
	if value == null:
		return true
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric_version := float(value)
	return is_finite(numeric_version) and numeric_version == float(VERSION)
