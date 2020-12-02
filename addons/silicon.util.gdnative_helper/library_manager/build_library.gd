tool
extends ConfirmationDialog

const FileEdit = preload("res://addons/silicon.util.gdnative_helper/utils/file_edit.tscn")

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

var building_lib_item: TreeItem
var prev_build_failed := false

func _ready() -> void:
	get_ok().text = "Build"
	connect("finished", self, "finish_task")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		$Container/Header/Label.get_stylebox("normal").bg_color = get_color("prop_category", "Editor") * 1.2


func _exit_tree() -> void:
	if thread.is_active():
		thread.wait_to_finish()


func _on_about_to_show() -> void:
	var library: String = main.current_library_item.get_text(0)
	generate_build_gui(library)


func _on_Architectures_toggled(button_pressed: bool, platform: String, arch: String) -> void:
	if button_pressed and not platforms[platform].has(arch):
		platforms[platform].append(arch)
	elif not button_pressed and platforms[platform].has(arch):
		platforms[platform].erase(arch)


func _on_Target_pressed(target: String) -> void:
	self.target = target


func _on_confirmed() -> void:
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


func generate_build_gui(lib_name: String) -> void:
	var library: Dictionary = main.solution.libraries[lib_name]
	var language: String = library.language
	
	var file := File.new()
	assert(file.open(main.languages[language].config_path, File.READ) == OK)
	var config: Dictionary = parse_json(file.get_as_text())
	var build_options: Dictionary = config.get("build_options", {})
	file.close()
	
	var options_container := $Container/Options/VBox
	for child in options_container.get_children():
		child.queue_free()
	
	for name in build_options:
		var option: Dictionary = build_options[name]
		var control: Control
		match typeof(option.value):
			TYPE_BOOL:
				control = CheckBox.new()
				control.pressed = option.value
				control.text = "On"
			TYPE_STRING:
				if option.has("hint") and option.hint.find("IS_FOLDER") != -1:
					control = FileEdit.instance()
					control.mode = FileDialog.MODE_OPEN_DIR
					control.file_dialog_node = $FileDialog
				else:
					control = LineEdit.new()
					control.text = option.value
		
		if control:
			var hbox := HBoxContainer.new()
			var label := Label.new()
			label.hint_tooltip = option.get("description", "")
			control.size_flags_horizontal = SIZE_EXPAND_FILL
			control.rect_clip_content = true
			hbox.size_flags_horizontal = SIZE_EXPAND_FILL
			label.size_flags_horizontal = SIZE_EXPAND_FILL
			label.clip_text = true
			label.mouse_filter = MOUSE_FILTER_STOP
			label.text = name.capitalize()
			hbox.add_child(label)
			hbox.add_child(control)
			options_container.add_child(hbox)


func update_targets_gui() -> void:
	for platform in platforms:
		for arch in platforms[platform]:
			var button_name: String = {
				"x86": "86",
				"x86_64": "86_64",
				"armv7": "arm7",
				"arm64v8": "arm8"
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
	
	var library: Dictionary = main.solution.libraries[building_lib_item.get_text(0)]
	var language: Dictionary = main.languages.get(library.language, null)
	if not language:
		printerr("This library doesn't have an assigned language!")
		call_deferred("finish_task")
		return ERR_DOES_NOT_EXIST
	
	var library_name: String = library.name
	var build_path: String = language.build_path
	var library_path: String = library.data_folder
	var lib_config: ConfigFile = library.native_lib.config_file
	
	var python := "python" if OS.has_feature("Windows") else "python3"
	if OS.execute(python, ["--version"], true, []):
		printerr("Python isn't installed or not part of your environment variables!")
		printerr("Please setup python and restart the editor after that.")
		call_deferred("finish_task")
		return ERR_DOES_NOT_EXIST
	
	for platform in platforms:
		var archs: Array = platforms[platform]
		for arch in archs:
			print("building library '%s' (%s, %s, %s)." % [library_name, platform, arch, target])
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
				ProjectSettings.globalize_path("res://addons/silicon.util.gdnative_helper/main_build.py"),
				build_path.get_base_dir(),
				language.config_path,
				library_name,
				ProjectSettings.globalize_path("%s/bin/lib-%s.%s.%s.%s" % [library_path, library_name, platform, target, arch]),
				ProjectSettings.globalize_path("%s/src" % library_path),
				extension, platform,
				arch, target
			], true, output, true)
			
			if exit:
				for out in output:
					printerr(out)
				prev_build_failed = true
				call_deferred("finish_task")
				return ERR_COMPILATION_FAILED
			
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
			
			lib_config.set_value("entry", lib_name, "%s/bin/lib-%s.%s.%s.%s.%s" % [library.data_folder, library_name, platform, target, arch, extension])
			lib_config.save(library.native_lib.resource_path)
	
	print("Built '%s' successfully!" % library_name)
	call_deferred("finish_task")
	return OK


func finish_task() -> void:
	var err: int = thread.wait_to_finish()
	OS.request_attention()
	main.set_build_status_icon(building_lib_item, get_icon("StatusError" if err else "StatusSuccess", "EditorIcons"))
	building_lib_item = null
	if not pending_tasks.empty():
		var next_task: Dictionary = pending_tasks.pop_back()
		thread.start(self, "build", next_task)
