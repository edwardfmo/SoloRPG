## Base class for all game system plugins.
## Extend this and override get_actions()/get_conditions() to publish
## available types for the editor autocomplete.
class_name Plugin
extends RefCounted


## Return an array of action type strings this plugin provides.
## e.g. ["dnd.damage", "dnd.heal"]
func get_actions() -> Array[String]:
	return []


## Return an array of condition type strings this plugin provides.
## e.g. ["dnd.hp_above", "dnd.has_item"]
func get_conditions() -> Array[String]:
	return []


## Handle an action. Override in subclass.
func handle_action(_action_name: String, _data: Dictionary, _context):
	pass


## Check a condition. Override in subclass.
func check_condition(_cond_name: String, _data: Dictionary, _context) -> bool:
	return true
