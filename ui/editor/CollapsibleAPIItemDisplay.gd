## Base class for collapsible API item displays (actions/conditions).
## Handles: collapsible header, type row, parameter rows, add param button.
class_name CollapsibleAPIItemDisplay
extends VBoxContainer

signal item_changed
signal remove_requested(idx: int)
signal rebuild_requested
signal toggle_collapsed(idx: int, collapsed: bool)

@export var _header_button: Button
@export var _margin: MarginContainer
@export var _content: VBoxContainer

var _collapsed: bool = true
var _idx: int = 0
var _action: Dictionary = {}
var _available_types: Array[String] = []
var _param_provider: Callable
var _entry_hints: Array[String] = []

var _type_row_scene = preload("res://ui/editor/ActionTypeRow.tscn")
var _param_row_scene = preload("res://ui/editor/ActionParamRow.tscn")


func setup(idx: int, action: Dictionary, config: Dictionary):
	_idx = idx
	_action = action
	_available_types = config.get("available_types", [])
	_param_provider = config.get("param_provider", Callable())
	_entry_hints = config.get("entry_hints", [])
	_collapsed = config.get("collapsed", true)


func _ready():
	_header_button.pressed.connect(_on_toggle)
	_update_header(_action.get("type", ""))
	_margin.visible = not _collapsed
	_build_content()


func _build_content():
	# Type row
	var type_row = _type_row_scene.instantiate()
	var type_field: HintedLineEdit = type_row.get_node("TypeField")
	var remove_btn: Button = type_row.get_node("RemoveButton")

	_configure_type_row(type_row)

	type_field.text = _action.get("type", "")
	type_field.hints = _available_types

	type_field.text_changed.connect(func(new_text):
		_action["type"] = new_text
		_update_header(new_text)
		item_changed.emit())

	type_field.text_submitted.connect(func(new_text):
		_ensure_mandatory_params(new_text)
		rebuild_requested.emit())

	type_field.hint_selected.connect(func(new_text):
		_ensure_mandatory_params(new_text)
		rebuild_requested.emit())

	remove_btn.pressed.connect(func():
		remove_requested.emit(_idx))

	_content.add_child(type_row)

	# Parameter rows
	_build_params()

	# Add parameter button
	var add_param_btn = Button.new()
	add_param_btn.text = "+ Param"
	add_param_btn.pressed.connect(func():
		_action["param"] = ""
		item_changed.emit()
		rebuild_requested.emit())
	_content.add_child(add_param_btn)

	var sep = HSeparator.new()
	_content.add_child(sep)


## Override point for subclasses to configure the type row (e.g. NOT toggle).
func _configure_type_row(_type_row: Node):
	pass


func _build_params():
	var mandatory_keys = _get_mandatory_keys(_action.get("type", ""))
	var optional_hints = _get_optional_keys(_action.get("type", ""))
	var param_directions = _get_param_directions(_action.get("type", ""))
	var param_enums = _get_param_enums(_action.get("type", ""))
	var params_container = VBoxContainer.new()

	for key in _action:
		if key == "type" or key == "or_above" or key == "negate":
			continue
		var is_mandatory = mandatory_keys.has(key)
		var original_key = key

		var param_row = _param_row_scene.instantiate()
		var dir_label: Label = param_row.get_node("DirectionLabel")
		var key_field: LineEdit = param_row.get_node("KeyField")
		var val_field: LineEdit = param_row.get_node("ValueField")
		var enum_field: OptionButton = param_row.get_node("EnumField")
		var del_btn: Button = param_row.get_node("DeleteButton")
		var spacer: Control = param_row.get_node("Spacer")

		# Direction indicator
		var direction = param_directions.get(key, "input")
		dir_label.text = ">" if direction == "input" else "<"
		dir_label.tooltip_text = "input" if direction == "input" else "output"

		# Key field
		key_field.text = key
		if is_mandatory:
			key_field.editable = false
			key_field.modulate = Color(0.7, 0.7, 0.7)
		else:
			if key_field is HintedLineEdit:
				key_field.hints = optional_hints
			var _renamed := {&"done": false}
			var _commit_key_rename = func():
				if _renamed[&"done"]:
					return
				var new_key = key_field.text
				if new_key == original_key or new_key == "":
					return
				_renamed[&"done"] = true
				var val = _action.get(original_key, "")
				_action.erase(original_key)
				_action[new_key] = val
				item_changed.emit()
				rebuild_requested.emit()
			key_field.text_submitted.connect(func(_t): _commit_key_rename.call())
			key_field.focus_exited.connect(_commit_key_rename)
			if key_field is HintedLineEdit:
				key_field.hint_selected.connect(func(_t): _commit_key_rename.call())

		# Value field: enum dropdown or text input
		if param_enums.has(original_key):
			val_field.visible = false
			enum_field.visible = true
			var enum_values = param_enums[original_key]
			for ev in enum_values:
				enum_field.add_item(ev)
			var current_val = str(_action[key])
			var idx = enum_values.find(current_val)
			if idx >= 0:
				enum_field.selected = idx
			enum_field.item_selected.connect(func(sel_idx):
				_action[original_key] = enum_values[sel_idx]
				item_changed.emit())
		else:
			if val_field is HintedLineEdit:
				val_field.hints = _entry_hints
				val_field.hint_prefix = "@"
				val_field.hint_selected.connect(func(new_val):
					_action[original_key] = new_val
					item_changed.emit())
			val_field.text = str(_action[key])
			val_field.text_changed.connect(func(new_val):
				if new_val.is_valid_float():
					_action[original_key] = new_val.to_float()
				else:
					_action[original_key] = new_val
				item_changed.emit())

		# Delete/spacer
		if is_mandatory:
			del_btn.visible = false
			spacer.visible = true
		else:
			del_btn.pressed.connect(func():
				_action.erase(original_key)
				item_changed.emit()
				rebuild_requested.emit())

		params_container.add_child(param_row)
	_content.add_child(params_container)


# --- Header ---

func _on_toggle():
	_collapsed = not _collapsed
	_margin.visible = not _collapsed
	_update_header(_action.get("type", ""))
	toggle_collapsed.emit(_idx, _collapsed)


func _update_header(type_name: String):
	var prefix = "▶ " if _collapsed else "▼ "
	var label = type_name if type_name != "" else "(empty)"
	_header_button.text = prefix + label


# --- Param helpers ---

func _ensure_mandatory_params(type: String):
	if not _param_provider.is_valid() or type == "":
		return
	var params = _param_provider.call(type)
	for p in params:
		if p.get("mandatory", false):
			if not _action.has(p["name"]):
				_action[p["name"]] = ""


func _get_mandatory_keys(type: String) -> Array[String]:
	var result: Array[String] = []
	if not _param_provider.is_valid() or type == "":
		return result
	var params = _param_provider.call(type)
	for p in params:
		if p.get("mandatory", false):
			result.append(p["name"])
	return result


func _get_optional_keys(type: String) -> Array[String]:
	var result: Array[String] = []
	if not _param_provider.is_valid() or type == "":
		return result
	var params = _param_provider.call(type)
	for p in params:
		if not p.get("mandatory", false):
			result.append(p["name"])
	return result


func _get_param_directions(type: String) -> Dictionary:
	var result: Dictionary = {}
	if not _param_provider.is_valid() or type == "":
		return result
	var params = _param_provider.call(type)
	for p in params:
		result[p["name"]] = p.get("direction", "input")
	return result


func _get_param_enums(type: String) -> Dictionary:
	var result: Dictionary = {}
	if not _param_provider.is_valid() or type == "":
		return result
	var params = _param_provider.call(type)
	for p in params:
		if p.has("enum"):
			result[p["name"]] = p["enum"]
	return result
