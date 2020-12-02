#include "%LIBRARY_NAME%.h"

{CLASS_TEMPLATE}
#include "%CLASS_FILE_NAME%.h"
{CLASS_TEMPLATE}

// GDNative supports a large collection of functions for calling back
// into the main Godot executable. In order for your module to have
// access to these functions, GDNative provides your application with
// a struct containing pointers to all these functions.
const godot_gdnative_core_api_struct *api = NULL;
const godot_gdnative_ext_nativescript_api_struct *nativescript_api = NULL;

// `gdnative_init` is a function that initializes our dynamic library.
// Godot will give it a pointer to a structure that contains various bits of
// information we may find useful among which the pointers to our API structures.
void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *p_options) {
	api = p_options->api_struct;

	// Find NativeScript extensions.
	for (int i = 0; i < api->num_extensions; i++) {
		switch (api->extensions[i]->type) {
			case GDNATIVE_EXT_NATIVESCRIPT: {
				nativescript_api = (godot_gdnative_ext_nativescript_api_struct *)api->extensions[i];
			}; break;
			default:
				break;
		};
	};
}

// `gdnative_terminate` which is called before the library is unloaded.
// Godot will unload the library when no object uses it anymore.
void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *p_options) {
	api = NULL;
	nativescript_api = NULL;
}

// `nativescript_init` is the most important function. Godot calls
// this function as part of loading a GDNative library and communicates
// back to the engine what objects we make available.
void GDN_EXPORT godot_nativescript_init(void *p_handle) {
{CLASS_TEMPLATE}
	// %CLASS_NAME%
    godot_instance_create_func %CLASS_NAME%_create = { NULL, NULL, NULL };
	%CLASS_NAME%_create.create_func = &_%CLASS_NAME%_constructor;
    godot_instance_destroy_func %CLASS_NAME%_destroy = { NULL, NULL, NULL };
	%CLASS_NAME%_destroy.destroy_func = &_%CLASS_NAME%_destructor;
    nativescript_api->godot_nativescript_register_class(p_handle, "%CLASS_NAME%", "%CLASS_BASE%", %CLASS_NAME%_create, %CLASS_NAME%_destroy);
    _%CLASS_NAME%_register_methods(nativescript_api, p_handle);
{CLASS_TEMPLATE}
}
