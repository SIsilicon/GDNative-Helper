tool
extends Control

onready var tree: Tree = $VBoxContainer/HSplitContainer/Tree

var libraries := {}
var current_library: GDNativeLibrary


func _ready() -> void:
	var root := tree.create_item()
	
	var test := tree.create_item(root)
	test.set_text(0, "Test Library")


func _on_CreateLib_pressed() -> void:
	$FileDialog.popup_centered_ratio()


func _on_DeleteLib_pressed() -> void:
	pass # Replace with function body.


func _on_Tree_item_selected() -> void:
	var item := tree.get_selected()
	current_library = libraries[item.get_text(0)]


func _on_FileDialog_file_selected(path: String) -> void:
	path = path.replacen("gdnlib", "")
	path += "gdnlib"
	var library := GDNativeLibrary.new()
	ResourceSaver.save(path, library, ResourceSaver.FLAG_CHANGE_PATH)
	print(library.resource_path)
	
	libraries[library.resource_path] = library
	var item := tree.create_item(tree.get_root())
	item.set_text(0, library.resource_name)

