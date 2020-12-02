#ifndef _%CLASS_NAME%_
#define _%CLASS_NAME%_

#include "%LIBRARY_NAME%.h"

typedef struct {
	// properties here
} %CLASS_NAME%;

void _%CLASS_NAME%_register_methods(void *p_handle);

// These are forward declarations for the functions we'll be implementing
// for our object. A constructor and destructor are both necessary.
GDCALLINGCONV void *%CLASS_NAME%_constructor(godot_object *this, void *p_method_data);
GDCALLINGCONV void %CLASS_NAME%_destructor(godot_object *this, void *p_method_data, void *p_user_data);

void _%CLASS_NAME%_ready(godot_object *this, void *p_method_data, void *this_data, int p_num_args, godot_variant **p_args);

#endif