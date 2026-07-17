extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --headless --path <inspector> --script res://inspect.gd -- <pack.pck>")
		quit(2)
		return
	var pack_path := ProjectSettings.globalize_path(args[0]) if args[0].begins_with("res://") else args[0]
	if !ProjectSettings.load_resource_pack(pack_path, true):
		printerr("Unable to load PCK: " + pack_path)
		quit(3)
		return
	_list_files("res://")
	quit()


func _list_files(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		printerr("Unable to open: " + path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_list_files(child)
			else:
				print(child)
		entry = directory.get_next()
	directory.list_dir_end()
