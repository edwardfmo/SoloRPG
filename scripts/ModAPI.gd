class_name ModAPI
extends RefCounted

var systems := {}

func register_system(name: String, system):
	systems[name] = system

func get_system(name: String):
	return systems.get(name, null)
