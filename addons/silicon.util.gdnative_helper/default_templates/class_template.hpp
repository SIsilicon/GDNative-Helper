#ifndef _%CLASS_NAME%_
#define _%CLASS_NAME%_

#include <Godot.hpp>
#include <%CLASS_BASE%.hpp>


class %CLASS_NAME% : public godot::%CLASS_BASE% {
	GODOT_CLASS(%CLASS_NAME%, godot::%CLASS_BASE%)

public:
	static void _register_methods();

	void _init();

	void _ready();
};

#endif