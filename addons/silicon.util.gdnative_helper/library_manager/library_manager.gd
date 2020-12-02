tool
extends Control

signal console_requested

onready var tree: Tree = $VBoxContainer/HSplitContainer/Tree

var languages := {}

var editor_file_system: EditorFileSystem
var data_dir: String
var tree_root: TreeItem

var current_library_item: TreeItem
var current_class_item: TreeItem

var solution_path := "res://native_solution.tres"
var solution: GDNativeSolution

func _ready() -> void:
	if not editor_file_system or not data_dir:
		return
	
	if ResourceLoader.exists(solution_path):
		solution = load(solution_path)
	else:
		solution = GDNativeSolution.new()
	solution.languages = languages
	
	tree_root = tree.create_item()
#	tree.set_column_expand(1, false)
#	tree.set_column_min_width(1, 24)
	_on_Reload_pressed()
	scan_languages()


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		pass
#		for tree_roo


func _on_CreateLib_pressed() -> void:
	$CreateLibraryDialog.popup_centered()


func _on_BuildLib_pressed() -> void:
	$BuildLibraryDialog.popup_centered()


func _on_OpenLibrary_pressed() -> void:
	var library_name := current_library_item.get_text(0)
	
	var lib_path: String = solution.libraries[library_name].source_file
	lib_path = ProjectSettings.globalize_path(lib_path)
	OS.shell_open(lib_path)


func _on_DeleteLib_pressed(confirmed := false) -> void:
	if confirmed:
		solution.delete_library(current_library_item.get_text(0))
		ResourceSaver.save(solution_path, solution, ResourceSaver.FLAG_CHANGE_PATH)
		editor_file_system.scan()
		_on_Reload_pressed()
	else:
		$DeleteLibraryDialog.dialog_text = "Delete library \"%s\" and its classes? \n Its source files and the classes' will be deleted as well." % current_library_item.get_text(0)
		$DeleteLibraryDialog.popup_centered()


func _on_Tree_item_selected() -> void:
	var item = tree.get_selected()
	if item.get_parent() == tree_root:
		current_library_item = tree.get_selected()
		current_class_item = null
	else:
		current_class_item = tree.get_selected()
		current_library_item = current_class_item.get_parent()
	update_buttons()


func _on_Tree_button_pressed(item: TreeItem, column: int, id: int) -> void:
	if id == 0:
		OS.shell_open(ProjectSettings.globalize_path(item.get_meta("source")))
	elif id == 1:
		emit_signal("console_requested")


func _on_Reload_pressed() -> void:
	reload_list()


func _on_CreateClass_pressed() -> void:
	$CreateClassDialog.popup_centered_ratio(0.3)

func _on_DeleteClass_pressed(confirmed := false) -> void:
	if confirmed:
		solution.delete_class(current_class_item.get_text(0))
		ResourceSaver.save(solution_path, solution, ResourceSaver.FLAG_CHANGE_PATH)
		editor_file_system.scan()
		_on_Reload_pressed()
	else:
		$DeleteClassDialog.dialog_text = "Delete class \"%s\"? \n Its source files will be deleted as well." % current_class_item.get_text(0)
		$DeleteClassDialog.popup_centered()


func _on_BuildIconUpdate_timeout() -> void:
	var lib_first_item := tree_root.get_next_visible(true)
	var lib_item := lib_first_item
	while lib_first_item:
		if lib_item.get_button_count(0) > 1:
			for i in range(0, 8):
				if lib_item.get_button(0, 1) == get_icon("Progress%d" % (i + 1), "EditorIcons"):
					set_build_status_icon(lib_item, get_icon("Progress%d" % ((i + 1) % 8 + 1), "EditorIcons"))
					break

		lib_item = tree_root.get_next_visible(true)
		if lib_item == lib_first_item:
			break


func reload_list() -> void:
	var root := tree_root
	while root.get_children():
		var child := root.get_children()
		root.remove_child(child)
		child.free()
	
	# Load libraries
	var libraries := solution.libraries
	for lib in libraries:
		var library = libraries[lib]
		var lib_item := tree.create_item(tree_root)
		lib_item.add_button(0, get_icon("Script", "EditorIcons"), 0, false, "Open Source File: " + library.source_file)
		lib_item.set_meta("source", library.source_file)
		lib_item.set_text(0, lib)
		
		var classes: Array = library.classes
		for cls in classes:
			var cls_item := tree.create_item(lib_item)
			cls_item.add_button(0, get_icon("Script", "EditorIcons"), 0, false, "Open Source File: " + solution.class_abs_source_file(solution.classes[cls]))
			cls_item.set_meta("source", solution.class_abs_source_file(solution.classes[cls]))
			cls_item.set_text(0, cls)
	
	current_library_item = null
	current_class_item = null
	update_buttons()


func list_files_in_directory(path: String, extension: String) -> Array:
	var files := []
	var dir := Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.begins_with("."):
				file = dir.get_next()
				continue
			elif file.get_extension() == extension:
				files.append(file)
			elif dir.current_is_dir():
				files += list_files_in_directory(file, extension)
			file = dir.get_next()
	dir.list_dir_end()
	
	return files


func set_build_status_icon(library_item: TreeItem, icon: Texture) -> void:
	var tooltip: String = {
		get_icon("StatusError", "EditorIcons"): "Build failed! Check the console for errors.",
		get_icon("StatusSuccess", "EditorIcons"): "Build successful!",
		get_icon("Progress1", "EditorIcons"): "Building...",
		get_icon("Progress2", "EditorIcons"): "Building...",
		get_icon("Progress3", "EditorIcons"): "Building...",
		get_icon("Progress4", "EditorIcons"): "Building...",
		get_icon("Progress5", "EditorIcons"): "Building...",
		get_icon("Progress6", "EditorIcons"): "Building...",
		get_icon("Progress7", "EditorIcons"): "Building...",
		get_icon("Progress8", "EditorIcons"): "Building...",
		null: ""
	}.get(icon, "icon error")
	
	library_item.erase_button(0, 1)
	library_item.add_button(0, icon, 1, false, tooltip)


func update_buttons() -> void:
	var library_selected := current_library_item != null
	var class_selected := current_class_item != null
	
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteLib.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/BuildLib.disabled = not (library_selected and current_library_item.get_children())
	$VBoxContainer/HSplitContainer/VBoxContainer/CreateClass.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteClass.disabled = not class_selected


func scan_languages() -> void:
	languages.clear()
	var dir := Directory.new()
	var lang_path_root: String = data_dir + '/' + "native_languages"
	if dir.open(lang_path_root):
		printerr("Could not open the language templates at %s!" % lang_path_root)
		return
	
	dir.list_dir_begin(true, true)
	var file_dir := dir.get_next()
	while file_dir:
		if not dir.current_is_dir():
			file_dir = dir.get_next()
			continue
		
		var language := {
			lib_templates = [],
			class_templates = [],
			build_path = ""
		}
		
		var lang_dir := Directory.new()
		lang_dir.open(dir.get_current_dir() + '/' + file_dir)
		lang_dir.list_dir_begin(true, true)
		var lang_file_dir := lang_dir.get_next()
		while lang_file_dir:
			if lang_dir.current_is_dir():
				lang_file_dir = lang_dir.get_next()
				continue
			
			var file_path = "%s/%s" % [lang_dir.get_current_dir(), lang_file_dir]
			
			if lang_file_dir.find("library_template") != -1:
				language.lib_templates.append(file_path)
			elif lang_file_dir.find("class_template") != -1:
				language.class_templates.append(file_path)
			elif lang_file_dir.find("build") != -1:
				language.build_path = file_path
			elif lang_file_dir.find("config.json") != -1:
				language.config_path = file_path
				
				var config_file := File.new()
				config_file.open(file_path, File.READ)
				var config: Dictionary = parse_json(config_file.get_as_text())
				language.source_extension = config.source_extension
				language.header_extension = config.get("header_extension", "")
				config_file.close()
			
			lang_file_dir = lang_dir.get_next()
		lang_dir.list_dir_end()
		
		languages[file_dir.get_basename()] = language
		
		file_dir = dir.get_next()
	dir.list_dir_end()
