tool
extends WindowDialog

onready var main: Control = get_parent()
onready var library_path: String = $Container/Path/LineEdit.text
onready var language: String = $Container/Language/OptionButton.get_item_text($Container/Language/OptionButton.get_selected_id())


func _on_about_to_show() -> void:
	$Container/Path/Button.icon = get_icon("Folder", "EditorIcons")
	update_configuration()


func _on_Language_item_selected(index: int) -> void:
	language = $Container/Language/OptionButton.get_item_text(index)


func _on_Path_pressed() -> void:
	$FileDialog.popup_centered_ratio(0.6)


func _on_FileDialog_file_selected(path: String) -> void:
	$Container/Path/LineEdit.text = path
	library_path = path
	update_configuration()


func _on_LineEdit_path_changed(new_text: String) -> void:
	library_path = new_text
	update_configuration()


func _on_Create_pressed() -> void:
	var file_path: String = library_path.replacen("gdnlib", "")
	file_path += "gdnlib"
	var lib_name: String = library_path.get_file().replace(".gdnlib", "")
	
	var library := GDNativeLibrary.new()
	library.config_file.set_value("entry", "Language", language)
	library.resource_name = lib_name
	library.resource_path = file_path
	ResourceSaver.save(file_path, library, ResourceSaver.FLAG_CHANGE_PATH)
	
	var item: TreeItem = main.tree.create_item(main.tree_root)
	item.set_selectable(1, false)
	item.set_text(0, lib_name)
	item.set_meta("library", library)
	item.set_meta("file_path", library.resource_path)
	item.set_meta("classes", {})
	
	main.generate_library(item)
	
	main.editor_file_system.scan()
	hide()


func _on_Cancel_pressed() -> void:
	hide()


func update_configuration() -> void:
	var message := ""
	var valid := true
	
	if library_path.get_file().is_valid_filename():
		message += "[color=#44FF44]- Library path/name is valid.[/color]\n"
	else:
		message += "[color=#FF0000]- Library path/name is invalid![/color]\n"
		valid = false
	
	if not library_path.get_extension() == "gdnlib":
		message += "[color=#FF0000]- The extension is not of a GDNativeLibrary(gdnlib)![/color]\n"
		valid = false
	
	$Container/Config.bbcode_text = message
	$Container/Buttons/Create.disabled = not valid
