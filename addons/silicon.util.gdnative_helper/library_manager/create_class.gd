tool
extends ConfirmationDialog

onready var main: Control = get_parent()
onready var cls_inherit: String = $Container/Inherit/LineEdit.text
onready var cls_path: String = $Container/Path/LineEdit.text
onready var cls_name: String = $Container/Name/LineEdit.text

func _on_about_to_show() -> void:
	$Container/Path/Button.icon = get_icon("Folder", "EditorIcons")
	get_ok().text = "Create"
	update_configuration()


func _on_Path_pressed() -> void:
	$FileDialog.popup_centered_ratio(0.6)


func _on_FileDialog_file_selected(path: String) -> void:
	$Container/Path/LineEdit.text = path
	cls_path = path
	update_configuration()


func _on_LineEdit_path_changed(new_text: String) -> void:
	cls_path = new_text
	update_configuration()


func _on_Create_pressed() -> void:
	var file_path: String = cls_path.replacen("gdns", "")
	file_path += "gdns"
	var lib_item: TreeItem = main.current_library_item
	var lib_name: String = lib_item.get_text(0)
	var lib_file: String = lib_item.get_meta("library").resource_path
	
	main.generate_class(lib_name, lib_file, cls_name, cls_inherit, cls_path.get_file().replacen(".gdns", ""))
	
	var library: GDNativeLibrary = lib_item.get_meta("library")
	var script := NativeScript.new()
	script.set("class_name", cls_name) # class_name is a keyword, so a setter is required here.
	script.set_meta("inherit", cls_inherit)
	script.library = library
	script.resource_name = cls_name
	script.resource_path = file_path
	ResourceSaver.save(file_path, script, ResourceSaver.FLAG_CHANGE_PATH)
	
	var item: TreeItem = main.tree.create_item(lib_item)
	item.set_selectable(1, false)
	item.set_text(0, cls_name)
	item.set_meta("class", script)
	item.set_meta("file_path", script.resource_path)
	lib_item.get_meta("classes")[cls_name] = script
	
	main.generate_library(main.current_library_item)
	
	main.editor_file_system.scan()
	hide()


func _on_LineEdit_name_changed(new_text: String) -> void:
	cls_name = new_text
	update_configuration()


func _on_LineEdit_inherit_changed(new_text: String) -> void:
	cls_inherit = new_text
	update_configuration()


func update_configuration() -> void:
	var message := ""
	var class_name_taken := false

	var classes: Dictionary = main.current_library_item.get_meta("classes")
	for cls in classes:
		if cls == cls_name:
			class_name_taken = true
			break
	
	var file := File.new()
	
	if not cls_path.get_file().is_valid_filename():
		message += "[color=#FF0000]- Class path is invalid![/color]\n"
	elif not cls_path.get_extension() == "gdns":
		message += "[color=#FF0000]- The extension is not of a NativeScript(gdns)![/color]\n"
	elif file.file_exists(cls_path):
		message += "[color=#FF0000]- A script at this path already exists![/color]\n"
	else:
		message += "[color=#44FF44]- Class path is valid.[/color]\n"
	
	if not ClassDB.class_exists(cls_inherit):
		message += "[color=#FF0000]- The inherited builtin class does not exist![/color]\n"
	
	if not cls_name.is_valid_identifier():
		message += "[color=#FF0000]- Invalid class name![/color]\n"
	elif ClassDB.class_exists(cls_name):
		message += "[color=#FF0000]- The class name is the same as a builtin class![/color]\n"
	elif class_name_taken:
		message += "[color=#FF0000]- This class name is already used in the selected library![/color]\n"
	else:
		message += "[color=#44FF44]- Class name is valid.[/color]\n"
	
	var valid = message.count("[color=#FF0000]") == 0
	$Container/Config.bbcode_text = message
	get_ok().disabled = not valid

