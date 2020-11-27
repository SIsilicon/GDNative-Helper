#include "%CLASS_FILE_NAME%.hpp"

void %CLASS_NAME%::_register_methods() {
	godot::register_method("_ready", &%CLASS_NAME%::_ready);
}

// This functions needs to exist whether you use it or not.
void %CLASS_NAME%::_init() {}

// Called when the node enters the scene tree for the first time.
void %CLASS_NAME%::_ready() {
}