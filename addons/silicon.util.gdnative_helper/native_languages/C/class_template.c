#include "%CLASS_FILE_NAME%.h"


void _%CLASS_NAME%_register_methods(godot_gdnative_ext_nativescript_api_struct native_api, void *p_handle) {
    godot_instance_method _ready = { NULL, NULL, NULL };
	_ready.method = &_%CLASS_NAME%_ready;
	godot_method_attributes attributes = { GODOT_METHOD_RPC_MODE_DISABLED };
	native_api->godot_nativescript_register_method(p_handle, "%CLASS_NAME%", "_ready", attributes, _ready);
}


// In our constructor, allocate memory for our structure and fill
// it with some data. Note that we use Godot's memory functions
// so the memory gets tracked and then return the pointer to
// our new structure. This pointer will act as our instance
// identifier in case multiple objects are instantiated.
GDCALLINGCONV void *_%CLASS_NAME%_constructor(godot_object *p_instance, void *p_method_data) {
	%CLASS_NAME% *user_data = api->godot_alloc(sizeof(%CLASS_NAME%));
	// Initialize data here
	return user_data;
}

// The destructor is called when Godot is done with our
// object and we free our instances' member data.
GDCALLINGCONV void _%CLASS_NAME%_destructor(godot_object *this, void *p_method_data, void *this_data) {
	// Free data here
	api->godot_free(this_data);
}


void _%CLASS_NAME%_ready(godot_object *this, void *p_method_data, void *this_data, int p_num_args, godot_variant **p_args) {
	
}
