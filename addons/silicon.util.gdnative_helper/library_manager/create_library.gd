tool
extends ConfirmationDialog

onready var main: Control = get_parent()
onready var library_path: String = $Container/Path/LineEdit.text
onready var language: String = $Container/Language/OptionButton.get_item_text($Container/Language/OptionButton.get_selected_id())

func _ready() -> void:
	get_ok().text = "Create"
	$Container/Path/Button.icon = get_icon("Folder", "EditorIcons")


func _on_about_to_show() -> void:
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


func _on_confirmed() -> void:
	var file_path: String = library_path.replacen("gdnlib", "")
	file_path += "gdnlib"
	var lib_name: String = library_path.get_file().replace(".gdnlib", "")
	
	main.solution.create_library(file_path, language)
	
	ResourceSaver.save(main.solution_path, main.solution, ResourceSaver.FLAG_CHANGE_PATH)
	main.editor_file_system.scan()
	main.reload_list()
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
	get_ok().disabled = not valid
