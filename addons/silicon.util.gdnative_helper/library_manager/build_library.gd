tool
extends WindowDialog

signal finished()

onready var main := get_parent()

var mutex := Mutex.new()
var thread := Thread.new()
var pending_tasks := []

var platforms := {
	windows = [],
	osx = [],
	linux = [],
	android = [],
	ios = []
}
var target := "debug"
onready var build_json_path: String = "%s/natvie_build_targets.json" % main.data_dir

var building_lib_item: TreeItem
var prev_build_failed := false


func _ready() -> void:
	var file := File.new()
	if file.file_exists(build_json_path):
		file.open(build_json_path, File.READ)
		var json := file.get_line()
		if validate_json(json).empty():
			platforms = parse_json(json)
		target = file.get_line()
		update_targets_gui()
		file.close()
	
	connect("finished", self, "finish_task")


func _exit_tree() -> void:
	if thread.is_active():
		thread.wait_to_finish()


func _on_Build_pressed() -> void:
	var task := {
		platforms = platforms,
		target = target,
		lib_item = main.current_library_item
	}
	
	if building_lib_item:
		pending_tasks.append(task)
	else:
		if thread.is_active():
			thread.wait_to_finish()
		thread.start(self, "build", task)
	hide()
	
	var file := File.new()
	file.open(build_json_path, File.WRITE)
	file.store_line(to_json(platforms))
	file.store_line(target)
	file.close()


func _on_Cancel_pressed() -> void:
	hide()


func _on_Architectures_toggled(button_pressed: bool, platform: String, arch: String) -> void:
	if button_pressed and not platforms[platform].has(arch):
		platforms[platform].append(arch)
	elif not button_pressed and platforms[platform].has(arch):
		platforms[platform].erase(arch)


func _on_Target_pressed(target: String) -> void:
	self.target = target


func update_targets_gui() -> void:
	for platform in platforms:
		for arch in platforms[platform]:
			var button_name: String = {
				"86": "x86",
				"86_64": "x86_64",
				"arm7": "armv7",
				"arm8": "arm64v8"
			}.get(arch, arch)
			
			var container := $Container/Platforms/Architectures.get_node({
				"windows": "Windows",
				"osx": "MacOS",
				"linux": "Linux",
				"android": "Android",
				"ios": "IOS",
			}[platform])
			container.get_node(button_name).pressed = true
	
	($Container/Target/Debug if target == "debug" else $Container/Target/Release).pressed = true

func build(data: Dictionary) -> int:
	var platforms: Dictionary = data.platforms
	var target: String = data.target
	
	building_lib_item = data.lib_item
	prev_build_failed = false
	
	var lib_config: ConfigFile = building_lib_item.get_meta("library").config_file
	
	print(lib_config.get_value("entry", "Language"))
	var language: Dictionary = main.languages.get(lib_config.get_value("entry", "Language"), null)
	if not language:
		printerr("This library doesn't have an assigned language!")
		call_deferred("finish_task")
	
	var library_name := building_lib_item.get_text(0)
	var build_path: String = language.build_path
	var library_path: String = ProjectSettings.globalize_path("%s/%s" % [main.LIBRARY_DATA_FOLDER, library_name])
	var python := "python" if OS.has_feature("Windows") else "python3"
	
	for platform in platforms:
		var archs: Array = platforms[platform]
		for arch in archs:
			print("building library '%s' (%s, %s, %s)." % [library_path, platform, arch, target])
			main.set_build_status_icon(building_lib_item, get_icon("Progress1", "EditorIcons"))
			var extension: String = {
				windows = "dll",
				osx = "dylib",
				linux = "so",
				android = "so",
				ios = "a"
			}[platform]
			
			var output := []
			var exit := OS.execute(python, [
				build_path,
				library_path,
				extension, platform,
				arch, target
			], true, output, true)
			
			if exit:
				for out in output:
					printerr(out)
				prev_build_failed = true
				main.set_build_status_icon(building_lib_item, get_icon("StatusError", "EditorIcons"))
				building_lib_item = null
				call_deferred("finish_task")
				OS.request_attention()
				return 1
			
			for out in output:
				print(out)
			var lib_name: String = {
				windows_32 = "Windows.32",
				windows_64 = "Windows.64",
				osx_64 = "OSX.64",
				linux_32 = "X11.32",
				linux_64 = "X11.64",
				android_armv7 = "Android.armeabi-v7a",
				android_arm64v8 = "Android.arm64-v8a",
				android_x86 = "Android.x86",
				android_x86_64 = "Android.x86_64",
				ios_armv7 = "iOS.armv7",
				ios_arm64v8 = "iOS.arm64"
			}[platform + "_" + arch]
			
			lib_config.set_value("entry", lib_name, "%s/%s/bin/lib-%s.%s.%s.%s.%s" % [main.LIBRARY_DATA_FOLDER, library_name, library_name, platform, target, arch, extension])
			lib_config.save(building_lib_item.get_meta("library").resource_path)
	
	print("Built '%s' successfully!" % library_name)
	OS.request_attention()
	main.set_build_status_icon(building_lib_item, get_icon("StatusSuccess", "EditorIcons"))
	building_lib_item = null
	call_deferred("finish_task")
	return 0


func finish_task() -> void:
	thread.wait_to_finish()
	if not pending_tasks.empty():
		var next_task: Dictionary = pending_tasks.pop_back()
		thread.start(self, "build", next_task)
