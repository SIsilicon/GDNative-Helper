tool
extends WindowDialog

onready var main := get_parent()

var thread := Thread.new()

var platforms := {
	windows = [],
	macos = [],
	linux = [],
	android = [],
	ios = []
}
var target := "debug"

var building := false

func _on_Build_pressed() -> void:
	thread.start(self, "build", [platforms, target, main.current_library_item.get_text(0)])
	hide()


func _on_Cancel_pressed() -> void:
	hide()


func _on_Architectures_toggled(button_pressed: bool, platform: String, arch: String) -> void:
	if button_pressed and not platforms[platform].has(arch):
		platforms[platform].append(arch)
	elif not button_pressed and platforms[platform].has(arch):
		platforms[platform].erase(arch)


func _on_Target_pressed(target: String) -> void:
	self.target = target


func build(data: Array) -> void:
	var platforms: Dictionary = data[0]
	var target: String = data[1]
	var library_name: String = data[2]
	
	var build_path := ProjectSettings.globalize_path("res://addons/gdnative_data/build.py")
	var library_path: String = "src/" + library_name
	
	for platform in platforms:
		var archs: Array = platforms[platform]
		for arch in archs:
			var bits := "32" if arch in ["32", "x86", "armv7-a"] else "64"
			building = true
			print("building... %s %s %s" % [platform, arch, target])
			
			var dir := Directory.new()
			dir.make_dir_recursive("res://addons/gdnative_data/bin")
			var file := File.new()
			file.open("res://addons/gdnative_data/bin/%s.%s.%s.%s" % [library_name, platform, target, bits], File.WRITE)
			file.close()
			
			var output := []
			var exit := OS.execute("python", [build_path, library_path, library_name, platform, bits, arch, target], true, output, true)
			dir.remove("res://addons/gdnative_data/bin/%s.%s.%s.%s" % [library_name, platform, target, bits])
			if exit:
				printerr(output)
	building = false
	print("finished!")
	finished_building()


func finished_building() -> void:
	thread.wait_to_finish()
	print("finished!")
