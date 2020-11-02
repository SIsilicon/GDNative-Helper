tool
extends WindowDialog

onready var main: Control = get_parent()
onready var cls_inherit: String = $Container/Inherit/LineEdit.text
onready var cls_path: String = $Container/Path/LineEdit.text
onready var cls_name: String = $Container/Name/LineEdit.text

func _on_about_to_show() -> void:
	$Container/Path/Button.icon = get_icon("Folder", "EditorIcons")
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
	
	main.generate_class(lib_name, cls_name, cls_inherit, cls_path.get_file().replacen(".gdns", ""))
	
	var library: GDNativeLibrary = lib_item.get_meta("library")
	var script := NativeScript.new()
	script.set("class_name", cls_name) # class_name is a keyword, so a setter is required here.
	script.set_meta("library", library)
	script.resource_name = cls_name
	script.resource_path = file_path
	ResourceSaver.save(file_path, script, ResourceSaver.FLAG_CHANGE_PATH)
	
	var item: TreeItem = main.tree.create_item(lib_item)
	item.set_text(0, cls_name)
	item.set_meta("class", script)
	item.set_meta("file_path", script.resource_path)
	print(script.resource_path)
	lib_item.get_meta("classes")[cls_name] = script
	
	# Regenerate library code
	var class_names := []
	var class_file_paths := []
	for cls in lib_item.get_meta("classes"):
		class_names.append(cls)
		var path = lib_item.get_meta("classes")[cls].resource_path
		prints(cls, path)
		class_file_paths.append(path)
	main.generate_library(lib_name, class_names, class_file_paths)
	
	main.editor_file_system.scan()
	hide()


func _on_Cancel_pressed() -> void:
	hide()


func update_configuration() -> void:
	var message := ""
	var valid := true
	
	if cls_path.get_file().is_valid_filename():
		message += "[color=#44FF44]- Library path/name is valid.[/color]\n"
	else:
		message += "[color=#FF0000]- Library path/name is invalid![/color]\n"
		valid = false
	
	if not cls_path.get_extension() == "gdns":
		message += "[color=#FF0000]- The extension is not of a NativeScript(gdns)![/color]\n"
		valid = false
	
	if not cls_name.is_valid_identifier():
		message += "[color=#FF0000]- Invalid class name![/color]\n"
		valid = false
	
	if not ClassDB.class_exists(cls_inherit):
		message += "[color=#FF0000]- The parent class is invalid![/color]\n"
		valid = false
	
	$Container/Config.bbcode_text = message
	$Container/Buttons/Create.disabled = not valid


func _on_LineEdit_name_changed(new_text: String) -> void:
	cls_name = new_text
	update_configuration()


func _on_LineEdit_inherit_changed(new_text: String) -> void:
	cls_inherit = new_text
	update_configuration()
