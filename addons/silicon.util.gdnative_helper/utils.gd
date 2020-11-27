tool
extends Object


static func get_data_dir() -> String:
	if OS.has_feature("Windows"):
		return "/%APPDATA%/Godot/"
	elif OS.has_feature("X11"):
		return "~/.local/share/godot/"
	elif OS.has_feature("OSX"):
		return "~/Library/Application Support/Godot/"
	return ""
