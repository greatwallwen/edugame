extends RefCounted

const VERSION := 1


static func defaults() -> Dictionary:
	return {
		"sfxEnabled": true,
		"sfxVolume": 0.4,
		"animationSpeed": 1.0,
		"reducedFlash": false
	}


static func validate(value: Dictionary) -> Dictionary:
	var result := defaults()
	result["sfxEnabled"] = bool(value.get("sfxEnabled", result.sfxEnabled))
	result["sfxVolume"] = clampf(float(value.get("sfxVolume", result.sfxVolume)), 0.0, 1.0)
	var speed := float(value.get("animationSpeed", result.animationSpeed))
	result["animationSpeed"] = 1.5 if is_equal_approx(speed, 1.5) else 1.0
	result["reducedFlash"] = bool(value.get("reducedFlash", result.reducedFlash))
	return result


static func load(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return defaults()
	var config := ConfigFile.new()
	if config.load(path) != OK or int(config.get_value("settings", "version", -1)) != VERSION:
		return defaults()
	return validate({
		"sfxEnabled": config.get_value("settings", "sfxEnabled", true),
		"sfxVolume": config.get_value("settings", "sfxVolume", 0.4),
		"animationSpeed": config.get_value("settings", "animationSpeed", 1.0),
		"reducedFlash": config.get_value("settings", "reducedFlash", false)
	})


static func save(path: String, value: Dictionary) -> bool:
	var settings := validate(value)
	var config := ConfigFile.new()
	config.set_value("settings", "version", VERSION)
	for key in settings:
		config.set_value("settings", key, settings[key])
	return config.save(path) == OK
