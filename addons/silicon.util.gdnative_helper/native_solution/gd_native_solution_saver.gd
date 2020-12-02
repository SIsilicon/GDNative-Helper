tool
#class_name GDNativeSolutionSaver
extends ResourceFormatSaver


func get_recognized_extensions(resource: Resource) -> PoolStringArray:
	return PoolStringArray(["gdnsln"])


func recognize(resource: Resource) -> bool:
	return resource is GDNativeSolution
