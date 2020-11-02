tool
extends Control

const LIBRARY_SRC_FOLDER = "res://addons/gdnative_data/src"
const LIBRARY_BIN_FOLDER = "res://addons/gdnative_data/bin"

const CPP_TEMPLATES_FOLDER = "res://addons/silicon.util.gdnative_helper/default_templates"

onready var tree: Tree = $VBoxContainer/HSplitContainer/Tree

var editor_file_system: EditorFileSystem
var tree_root: TreeItem

var current_library_item: TreeItem
var current_class_item: TreeItem


func _ready() -> void:
	tree_root = tree.create_item()
	_on_Reload_pressed()


func _on_CreateLib_pressed() -> void:
	$CreateLibraryDialog.popup_centered()


func _on_BuildLib_pressed() -> void:
	$BuildLibraryDialog.popup_centered()


func _on_DeleteLib_pressed() -> void:
	while current_library_item.get_children():
		current_class_item = current_library_item.get_children()
		_on_DeleteClass_pressed()
	
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
		item.set_text(0, library.resource_name)
		item.set_meta("library", library)
		item.set_meta("file_path", library.resource_path)
		item.set_meta("classes", {})
		library_items[library] = item
	
	files = list_files_in_directory("res://", "gdns")
	for file in files:
		var script: NativeScript = load(file)
		if not script or not script.get_meta("library"):
			continue
		if script.resource_name.empty():
			script.resource_name = script.get("class_name")
		if library_items.has(script.get_meta("library")):
			var item := tree.create_item(library_items[script.get_meta("library")])
			item.set_text(0, script.resource_name)
			item.set_meta("class", script)
			item.set_meta("file_path", script.resource_path)
			library_items[script.get_meta("library")].get_meta("classes")[script.resource_name] = script
	
	current_library_item = null
	current_class_item = null
	update_buttons()


func _on_CreateClass_pressed() -> void:
	$CreateClassDialog.popup_centered_ratio(0.3)


func _on_EditClass_pressed() -> void:
	var class_file_name: String = current_class_item.get_meta("class").resource_path.get_file().replacen(".gdns", "")
	var library_name := current_library_item.get_text(0)
	
	var class_path := LIBRARY_SRC_FOLDER.plus_file(library_name)
	class_path = class_path.plus_file(class_file_name + ".cpp")
	class_path = ProjectSettings.globalize_path(class_path)
	
	OS.execute("cmd.exe", ["/c", class_path], false)


func _on_DeleteClass_pressed() -> void:
	var class_path: String = current_class_item.get_meta("class").resource_path
	
	current_library_item.get_meta("classes").erase(current_class_item.get_meta("class"))
	current_library_item.remove_child(current_class_item)
	current_class_item.free()
	current_class_item = null
	tree.hide()
	tree.show()
	
	var directory := Directory.new()
	directory.remove(class_path)
	editor_file_system.scan()
	
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


func generate_class(lib_name: String, cls_name: String, cls_base: String, cls_file: String) -> void:
	var dir := Directory.new()
	dir.make_dir_recursive(LIBRARY_SRC_FOLDER.plus_file(lib_name))
	
	var class_source: String
	var class_header: String
	
	# Class source
	var file := File.new()
	var error := file.open(CPP_TEMPLATES_FOLDER.plus_file("class_template.cpp"), File.READ)
	if not error:
		class_source = file.get_as_text()
	else:
		printerr("Failed to load template at: '%s'! Returned error code: %d." % [CPP_TEMPLATES_FOLDER.plus_file("class_template.cpp"), error])
		file.close()
		return 
	file.close()
	class_source = class_source.replace("%CLASS_NAME%", cls_name)
	class_source = class_source.replace("%CLASS_FILE_NAME%", cls_file)
	class_source = class_source.replace("%CLASS_BASE%", cls_base)
	file.open(LIBRARY_SRC_FOLDER.plus_file(lib_name).plus_file(cls_file + ".cpp"), File.WRITE)
	file.store_string(class_source)
	file.close()
	
	# Class header
	error = file.open(CPP_TEMPLATES_FOLDER.plus_file("class_template.hpp"), File.READ)
	if not error:
		class_header = file.get_as_text()
	else:
		printerr("Failed to load template at: '%s'! Returned error code: %d." % [CPP_TEMPLATES_FOLDER.plus_file("class_template.hpp"), error])
		file.close()
		return 
	file.close()
	class_header = class_header.replace("%CLASS_NAME%", cls_name)
	class_header = class_header.replace("%CLASS_FILE_NAME%", cls_file)
	class_header = class_header.replace("%CLASS_BASE%", cls_base)
	file.open(LIBRARY_SRC_FOLDER.plus_file(lib_name).plus_file(cls_file + ".hpp"), File.WRITE)
	file.store_string(class_header)
	file.close()


func generate_library(lib_name: String, class_names := [], class_file_paths := []) -> void:
	var dir := Directory.new()
	dir.make_dir_recursive(LIBRARY_SRC_FOLDER.plus_file(lib_name))
	
	var library_code: String
	var file := File.new()
	var error := file.open(CPP_TEMPLATES_FOLDER.plus_file("library_template.cpp"), File.READ)
	if not error:
		library_code = file.get_as_text()
	else:
		printerr("Failed to load CPP template at: '%s'! Returned error code: %d." % [CPP_TEMPLATES_FOLDER.plus_file("library_template.cpp"), error])
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
			replace = replace.replace("%CLASS_FILE_NAME%", class_file_paths[j].get_file().replacen(".gdns", ""))
			library_code = library_code.insert(result.get_start(), replace + "\n")
	
	file.open(LIBRARY_SRC_FOLDER.plus_file(lib_name).plus_file(lib_name + ".cpp"), File.WRITE)
	file.store_string(library_code)
	file.close()


func update_buttons() -> void:
	var library_selected := current_library_item != null
	var class_selected := current_class_item != null
	
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteLib.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/BuildLib.disabled = not (library_selected and current_library_item.get_children())
	$VBoxContainer/HSplitContainer/VBoxContainer/CreateClass.disabled = not library_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/EditClass.disabled = not class_selected
	$VBoxContainer/HSplitContainer/VBoxContainer/DeleteClass.disabled = not class_selected


func _on_Architectures_toggled(extra_arg_0: String, extra_arg_1: String) -> void:
	pass # Replace with function body.
