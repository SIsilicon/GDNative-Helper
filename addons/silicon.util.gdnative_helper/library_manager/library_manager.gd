tool
extends Control

const LIBRARY_DATA_FOLDER = "res://addons/gdnative_data"

onready var tree: Tree = $VBoxContainer/HSplitContainer/Tree

signal console_opened

var languages := {}

var editor_file_system: EditorFileSystem
var data_dir: String
var tree_root: TreeItem

var current_library_item: TreeItem
var current_class_item: TreeItem

func _ready() -> void:
	if not editor_file_system or not data_dir:
		return
	
	tree_root = tree.create_item()
	tree.set_column_expand(1, false)
	tree.set_column_min_width(1, 24)
	_on_Reload_pressed()


func _on_CreateLib_pressed() -> void:
	$CreateLibraryDialog.popup_centered()


func _on_BuildLib_pressed() -> void:
	$BuildLibraryDialog.popup_centered()


func _on_OpenLibrary_pressed() -> void:
	var lib_file_name: String = current_library_item.get_meta("library").resource_path.get_file().replacen(".gdnlib", "")
	var library_name := current_library_item.get_text(0)
	
	var lib_path := '%s/%s/src' % [LIBRARY_DATA_FOLDER, library_name]
	lib_path = ProjectSettings.globalize_path(lib_path)
	OS.shell_open(lib_path)


func _on_DeleteLib_pressed(confirmed := false) -> void:
	if confirmed:
		while current_library_item.get_children():
			current_class_item = current_library_item.get_children()
			_on_DeleteClass_pressed(true)
		
		var library_path: String = current_library_item.get_meta("library").resource_path
		
		tree_root.remove_child(current_library_item)
		current_library_item.free()
		current_library_item = null
		tree.hide()
		tree.show()
		
		var directory := Directory.new()
		directory.remove(library_path)
		editor_file_system.scan()
		
		update_buttons()
	else:
		$DeleteLibraryDialog.dialog_text = "Delete library \"%s\" and its classes? \n Its source files and the classes' will remain where they are." % current_library_item.get_text(0)
		$DeleteLibraryDialog.popup_centered()


func _on_Tree_item_selected() -> void:
	var item = tree.get_selected()
	if item.has_meta("library"):
		current_library_item = tree.get_selected()
		current_class_item = null
	elif item.has_meta("class"):
		current_class_item = tree.get_selected()
		current_library_item = current_class_item.get_parent()
	update_buttons()


func _on_Reload_pressed() -> void:
	var root := tree_root
	while root.get_children():
		var child := root.get_children()
		root.remove_child(child)
		child.free()
	
	# Load libraries
	var files := list_files_in_directory("res://", "gdnlib")
	var library_items := {}
	for file in files:
		var library: GDNativeLibrary = load(file)
		if not library:
			continue
		if library.resource_name.empty():
			library.resource_name = file.get_file().replace(".gdnlib", "")
		var item := tree.create_item(tree_root)
		item.set_selectable(1, false)
		item.set_text(0, library.resource_name)
		item.set_meta("library", library)
		item.set_meta("file_path", library.resource_path)
		item.set_meta("classes", {})
		library_items[library] = item
	
	files = list_files_in_directory("res://", "gdns")
	for file in files:
		var script: NativeScript = load(file)
		if not script or not script.library:
			continue
		if script.resource_name.empty():
			script.resource_name = script.get("class_name")
		if library_items.has(script.library):
			var item := tree.create_item(library_items[script.library])
			item.set_selectable(1, false)
			item.set_text(0, script.resource_name)
			item.set_meta("class", script)
			item.set_meta("file_path", script.resource_path)
			library_items[script.library].get_meta("classes")[script.resource_name] = script
	
	current_library_item = null
	current_class_item = null
	update_buttons()
	scan_languages()


func _on_CreateClass_pressed() -> void:
	$CreateClassDialog.popup_centered_ratio(0.3)

func _on_DeleteClass_pressed(confirmed := false) -> void:
	if confirmed:
		var class_path: String = current_class_item.get_meta("class").resource_path
		
		current_library_item.get_meta("classes").erase(current_class_item.get_text(0))
		current_library_item.remove_child(current_class_item)
		current_class_item.free()
		current_class_item = null
		tree.hide()
		tree.show()
		
		var directory := Directory.new()
		directory.remove(class_path)
		editor_file_system.scan()
		
		generate_library(current_library_item)
		update_buttons()
	else:
		$DeleteClassDialog.dialog_text = "Delete class \"%s\"? \n Its source files will remain where they are." % current_class_item.get_text(0)
		$DeleteClassDialog.popup_centered()


func _on_BuildIconUpdate_timeout() -> void:
	var lib_first_item := tree_root.get_next_visible(true)
	var lib_item := lib_first_item
	while lib_first_item:
		if lib_item.get_button_count(1):
			for i in range(0, 8):
				if lib_item.get_button(0, 0) == get_icon("Progress%d" % (i + 1), "EditorIcons"):
					set_build_status_icon(lib_item, get_icon("Progress%d" % ((i + 1) % 8 + 1), "EditorIcons"))
					break
		
		lib_item = tree_root.get_next_visible(true)
		if lib_item == lib_first_item:
			break


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


func generate_class(lib_name: String, lib_file: String, cls_name: String, cls_base: String, cls_file: String) -> void:
	var dir := Directory.new()
	dir.make_dir_recursive("%s/%s/src" % [LIBRARY_DATA_FOLDER, lib_name])

	var language: Dictionary = languages[load(lib_file).config_file.get_value("entry", "Language")]

	var class_source: String
	var class_header: String

	# Class source
	var file := File.new()
	for template in language.class_templates:
		var error := file.open(template, File.READ)
		if not error:
			class_source = file.get_as_text()
		else:
			printerr("Failed to load template at: '%s'! Returned error code: %d." % [template, error])
			file.close()
			return 
		file.close()
		class_source = class_source.replace("%CLASS_NAME%", cls_name)
		class_source = class_source.replace("%CLASS_FILE_NAME%", cls_file)
		class_source = class_source.replace("%CLASS_BASE%", cls_base)
		class_source = class_source.replace("%LIBRARY_FILE_NAME%", lib_file.get_file().replace(".gdnlib", ""))

		file.open("%s/%s/src/%s.%s" % [LIBRARY_DATA_FOLDER, lib_name, cls_file, template.get_extension()], File.WRITE)
		file.store_string(class_source)
		file.close()


func generate_library(lib_item: TreeItem) -> void:
	var lib_name := lib_item.get_text(0)
	var class_names := []
	var class_bases := []
	var class_file_paths := []
	for cls in lib_item.get_meta("classes"):
		class_names.append(cls)
		var script = lib_item.get_meta("classes")[cls]
		class_file_paths.append(script.resource_path)
		class_bases.append(script.get_meta("inherit"))

	var lang_name: String = lib_item.get_meta("library").config_file.get_value("entry", "Language")
	var language: Dictionary = languages[lang_name]

	var dir := Directory.new()
	dir.make_dir_recursive("%s/%s/src" % [LIBRARY_DATA_FOLDER, lib_name])
	
	var library_code: String
	var file := File.new()
	
	for template in language.lib_templates:
		var error := file.open(template, File.READ)
		if not error:
			library_code = file.get_as_text()
		else:
			printerr("Failed to load template at: '%s'! Returned error code: %d." % [template, error])
			file.close()
			return 
		file.close()
		
		var regex := RegEx.new()
		regex.compile("\\{CLASS_TEMPLATE\\}\\n([\\S\\s]+?)\\n\\{CLASS_TEMPLATE\\}")
		var matches := regex.search_all(library_code)
		
		for i in range(matches.size() - 1, -1, -1):
			var result: RegExMatch = matches[i]
			var sub := result.get_string(1)
			library_code.erase(result.get_start(), len(result.get_string()))
			
			for j in class_names.size():
				var replace := sub.replace("%CLASS_NAME%", class_names[j])
				replace = replace.replace("%CLASS_BASE%", class_bases[j])
				replace = replace.replace("%CLASS_FILE_NAME%", class_file_paths[j].get_file().replacen(".gdns", ""))
				replace = replace.replace("%LIBRARY_FILE_NAME%", lib_item.get_meta("file_path").get_file().replace(".gdnlib", ""))
				library_code = library_code.insert(result.get_start(), replace + "\n")
		
		file.open("%s/%s/src/%s.%s" % [LIBRARY_DATA_FOLDER, lib_name, lib_name, template.get_extension()], File.WRITE)
		file.store_string(library_code)
		file.close()
	
	# Generate a .gdignore along side the source code.
	file.open("%s/%s/src/.gdignore" % [LIBRARY_DATA_FOLDER, lib_name], File.WRITE)
	file.close()


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
	
	if not library_item.get_button_count(0):
		library_item.add_button(0, icon, 0)
	else:
		library_item.set_button(0, 0, icon)
	library_item.set_tooltip(1, tooltip)


func update_buttons() -> void:
	var library_selected := current_library_item != null
	var class_selected := current_class_item != null
	
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteLib.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/BuildLib.disabled = not (library_selected and current_library_item.get_children())
	$VBoxContainer/HSplitContainer/VBoxContainer/OpenLib.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/CreateClass.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteClass.disabled = not class_selected


func scan_languages() -> void:
	languages = {}
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
			
			if lang_file_dir.find("library_template") != -1:
				language.lib_templates.append(lang_dir.get_current_dir() + '/' + lang_file_dir)
			elif lang_file_dir.find("class_template") != -1:
				language.class_templates.append(lang_dir.get_current_dir() + '/' + lang_file_dir)
			elif lang_file_dir.find("build") != -1:
				language.build_path = lang_dir.get_current_dir() + '/' + lang_file_dir
			
			lang_file_dir = lang_dir.get_next()
		lang_dir.list_dir_end()
		
		languages[file_dir.get_basename()] = language
		
		file_dir = dir.get_next()
	dir.list_dir_end()


func _on_Tree_button_pressed(item: TreeItem, column: int, id: int) -> void:
	emit_signal("console_opened")
