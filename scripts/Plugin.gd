## Base class for all game system plugins.
## Extend this and override get_actions()/get_conditions() to publish
## available types for the editor autocomplete.
class_name Plugin
extends RefCounted

## Reference to the ModAPI, set automatically on registration.
var api: ModAPI = null


## Return an array of action type strings this plugin provides.
## e.g. ["dnd.take_damage", "dnd.heal"]
func get_actions() -> Array[String]:
	return []


## Return an array of condition type strings this plugin provides.
## e.g. ["dnd.hp_above", "dnd.has_item"]
func get_conditions() -> Array[String]:
	return []


## Return an array of UI panel declarations.
## Each entry: {slot: String, scene: String, id: String}
## Slots: "game_hud", "game_overlay"
func get_ui_panels() -> Array[Dictionary]:
	return []


## Handle an action. Override in subclass.
func handle_action(_action_name: String, _data: Dictionary, _context):
	pass


## Check a condition. Override in subclass.
func check_condition(_cond_name: String, _data: Dictionary, _context) -> bool:
	return true


## Return parameter schema for an action.
## Each entry: {name: String, mandatory: bool, direction: "input"|"output"}
## direction defaults to "input" if omitted. Output params store their value
## in context at the dot-path specified by the user (e.g. "combat.last_damage").
func get_action_params(_action_name: String) -> Array[Dictionary]:
	return []


## Return parameter schema for a condition.
## Each entry: {name: String, mandatory: bool, direction: "input"|"output"}
func get_condition_params(_cond_name: String) -> Array[Dictionary]:
	return []


## Called when a new game starts. Override to initialize context variables.
func on_game_start(_context: Dictionary):
	pass


## Called when game context changes (after entering a node or choice action).
func on_context_changed(_context: Dictionary):
	pass


## Called just before a choice is executed. Use for pre-choice saves.
func on_pre_choice(_context: Dictionary):
	pass
