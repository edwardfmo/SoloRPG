## Base editor for an array of {type, ...params} dictionaries.
## Subclassed by ActionListEditor and ConditionListEditor.
class_name APIItemListEditor
extends VBoxContainer

signal list_changed

## Autocomplete suggestions for the type field.
var available_types: Array[String] = []

## Callable that returns Array[Dictionary] of {name, mandatory, direction} for a type string.
## Signature: func(type: String) -> Array[Dictionary]
var param_provider: Callable

## Entry hints for value fields (e.g. ["@srd_equipment.longsword", ...]).
var entry_hints: Array[String] = []

var _actions: Array = []
@export var _container: VBoxContainer
@export var _add_button: Button
var _collapsed_state: Dictionary = {}  # action_idx → bool (true = collapsed)


func _ready():
	if _add_button:
		_add_button.pressed.connect(_on_add)


func set_actions(actions: Array):
	_actions = actions
	rebuild()


func get_actions() -> Array:
	return _actions


## Override in subclass to return the correct display scene.
func _get_display_scene() -> PackedScene:
	return null


## Override in subclass to provide extra config keys for the display.
func _get_extra_config(_idx: int) -> Dictionary:
	return {}


func rebuild():
	for child in _container.get_children():
		child.queue_free()

	for ai in _actions.size():
		var action = _actions[ai] if _actions[ai] is Dictionary else {"type": str(_actions[ai])}
		_actions[ai] = action

		var display: CollapsibleAPIItemDisplay = _get_display_scene().instantiate()

		var config = {
			"available_types": available_types,
			"param_provider": param_provider,
			"entry_hints": entry_hints,
			"collapsed": _collapsed_state.get(ai, true),
		}
		config.merge(_get_extra_config(ai))

		display.setup(ai, action, config)

		display.item_changed.connect(func(): list_changed.emit())
		display.remove_requested.connect(func(idx):
			_actions.remove_at(idx)
			_collapsed_state.erase(idx)
			list_changed.emit()
			rebuild())
		display.rebuild_requested.connect(func(): rebuild())
		display.toggle_collapsed.connect(func(idx, collapsed):
			_collapsed_state[idx] = collapsed)

		_container.add_child(display)


func _on_add():
	_actions.append({"type": ""})
	_collapsed_state[_actions.size() - 1] = false
	list_changed.emit()
	rebuild()
