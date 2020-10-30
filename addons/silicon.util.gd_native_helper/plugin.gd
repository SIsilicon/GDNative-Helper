tool
extends EditorPlugin

var library_manager: Control


func _enter_tree() -> void:
	library_manager = preload("library_manager.tscn").instance()
	add_control_to_bottom_panel(library_manager, "GDNative")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(library_manager)
