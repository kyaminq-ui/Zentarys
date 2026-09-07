// Le point d'entree de l'extension.
//
// Une seule classe pour l'instant, et c'est delibere : la cible du portage est
// **unique et chiffree** — `CWValueNoise.sample`, la moitie du temps de
// generation. Porter la dispersion, la palette ou la carte n'acheterait rien,
// et chaque classe portee est une frontiere de plus a tenir d'accord avec sa
// moitie GDScript.

#include "cw_noise.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_zentarys_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(zentarys::CWNoiseNative);
}

void uninitialize_zentarys_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT zentarys_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(
			p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_zentarys_module);
	init_obj.register_terminator(uninitialize_zentarys_module);
	init_obj.set_minimum_library_initialization_level(
			MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
