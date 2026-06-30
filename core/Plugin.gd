## Base class for all game system plugins.
## Extend this and override get_actions()/get_conditions() to publish
## available types for the editor autocomplete.
class_name Plugin
extends RefCounted

## Reference to the ModAPI, set automatically on registration.
var api: ModAPI = null

## The directory where this plugin resides (e.g. "res://plugins/dnd" or "user://plugins/dnd").
## Set automatically by the PluginLoader. Use resolve_path() to build full paths.
var plugin_dir: String = ""


## Resolves a relative path against this plugin's directory.
## e.g. resolve_path("HpBar.tscn") -> "res://plugins/dnd/HpBar.tscn"
func resolve_path(relative_path: String) -> String:
	return plugin_dir.path_join(relative_path)


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
func handle_action(_action_name: String, _data: Dictionary):
	pass


## Check a condition. Override in subclass.
func check_condition(_cond_name: String, _data: Dictionary) -> bool:
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


## Return template definitions this plugin provides.
## Each entry: {id: String, name: String, fields: [{name, type, mandatory}]}
func get_templates() -> Array[Dictionary]:
	return []


## Return seed entries for templates this plugin defines.
## Format: {template_id: [{field: value, ...}, ...]}
func get_template_entries() -> Dictionary:
	return {}


## Return a custom Control for rendering an item_schema object in the editor.
## Return null to use the default generic renderer.
## context: {entry, comp_id, entry_id, editable, on_changed: Callable, ref_hints: Callable}
func create_item_panel(template_id: String, field_name: String, item: Dictionary, context: Dictionary) -> Control:
	return null


## Return a custom summary string for an item_schema object header.
## Return "" to use the default header_format or fallback.
func get_item_summary(template_id: String, field_name: String, item: Dictionary) -> String:
	return ""


## Return setting definitions this plugin provides.
## Each entry: {path: String, label: String, type: "int"|"float"|"string"|"bool"|"enum",
##              scope: "global"|"module", default: Variant, options?: Array[String]}
## The plugin id is added automatically during registration.
func get_settings() -> Array[Dictionary]:
	return []


## Called when a new game starts. Override to initialize context variables.
## Return a Signal to block game start until the signal is emitted.
func on_game_start():
	pass


## Called when game context changes (after entering a node or choice action).
func on_context_changed():
	pass


## Called just before a choice is executed. Use for pre-choice saves.
func on_pre_choice():
	pass
