## Reusable editor for an array of {type, ...params} dictionaries.
## Used for on_enter actions and choice conditions.
extends VBoxContainer

signal list_changed

## Set this before calling set_actions() to provide autocomplete suggestions.
## e.g. ["dnd.damage", "dnd.hp_above"]
var available_types: Array[String] = []

## Callable that returns Array[Dictionary] of {name, mandatory} for a type string.
## Set this to enable auto-param injection. Signature: func(type: String) -> Array[Dictionary]
var param_provider: Callable

var _actions: Array = []
var _container: VBoxContainer


func _ready():
	_ensure_initialized()


func _ensure_initialized():
	if _container:
		return
	_container = VBoxContainer.new()
	add_child(_container)

	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.pressed.connect(_on_add)
	add_child(add_btn)


func set_actions(actions: Array):
	_ensure_initialized()
	_actions = actions
	rebuild()


func get_actions() -> Array:
	return _actions


func rebuild():
	for child in _container.get_children():
		child.queue_free()

	for ai in _actions.size():
		var action_idx = ai
		var action = _actions[ai] if _actions[ai] is Dictionary else {"type": str(_actions[ai])}
		_actions[ai] = action

		var action_box = VBoxContainer.new()

		# Type row
		var type_row = HBoxContainer.new()
		var type_field = HintedLineEdit.new()
		type_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		type_field.text = action.get("type", "")
		type_field.placeholder_text = "system.function"
		type_field.hints = available_types

		type_field.text_changed.connect(func(new_text):
			_actions[action_idx]["type"] = new_text
			list_changed.emit())

		type_field.text_submitted.connect(func(new_text):
			_ensure_mandatory_params(action_idx, new_text)
			rebuild())

		type_field.hint_selected.connect(func(new_text):
			_ensure_mandatory_params(action_idx, new_text)
			rebuild())

		type_row.add_child(type_field)

		var remove_btn = Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(func():
			_actions.remove_at(action_idx)
			list_changed.emit()
			rebuild())
		type_row.add_child(remove_btn)
		action_box.add_child(type_row)

		# Parameter rows
		var mandatory_keys = _get_mandatory_keys(action.get("type", ""))
		var params_container = VBoxContainer.new()
		for key in action:
			if key == "type":
				continue
			var is_mandatory = mandatory_keys.has(key)
			var param_row = HBoxContainer.new()
			var key_field = LineEdit.new()
			key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			key_field.text = key
			key_field.placeholder_text = "key"
			if is_mandatory:
				key_field.editable = false
				key_field.modulate = Color(0.7, 0.7, 0.7)
			var val_field = LineEdit.new()
			val_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val_field.text = str(action[key])
			val_field.placeholder_text = "value"
			var original_key = key
			if not is_mandatory:
				var _commit_key_rename = func():
					var new_key = key_field.text
					if new_key == original_key or new_key == "":
						return
					var val = _actions[action_idx].get(original_key, "")
					_actions[action_idx].erase(original_key)
					_actions[action_idx][new_key] = val
					list_changed.emit()
					rebuild()
				key_field.text_submitted.connect(func(_t): _commit_key_rename.call())
				key_field.focus_exited.connect(_commit_key_rename)
			val_field.text_changed.connect(func(new_val):
				var k = key_field.text if key_field.text != "" else original_key
				if new_val.is_valid_float():
					_actions[action_idx][k] = new_val.to_float()
				else:
					_actions[action_idx][k] = new_val
				list_changed.emit())
			param_row.add_child(key_field)
			param_row.add_child(val_field)
			if is_mandatory:
				# Spacer to keep alignment but no delete button
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(24, 0)
				param_row.add_child(spacer)
			else:
				var del_param_btn = Button.new()
				del_param_btn.text = "-"
				del_param_btn.pressed.connect(func():
					_actions[action_idx].erase(original_key)
					list_changed.emit()
					rebuild())
				param_row.add_child(del_param_btn)
			params_container.add_child(param_row)
		action_box.add_child(params_container)

		# Add parameter button
		var add_param_btn = Button.new()
		add_param_btn.text = "+ Param"
		add_param_btn.pressed.connect(func():
			_actions[action_idx]["param"] = ""
			list_changed.emit()
			rebuild())
		action_box.add_child(add_param_btn)

		var sep = HSeparator.new()
		action_box.add_child(sep)
		_container.add_child(action_box)


func _on_add():
	_actions.append({"type": ""})
	list_changed.emit()
	rebuild()


func _get_mandatory_keys(type: String) -> Array[String]:
	var result: Array[String] = []
	if not param_provider.is_valid() or type == "":
		return result
	var params = param_provider.call(type)
	for p in params:
		if p.get("mandatory", false):
			result.append(p["name"])
	return result


func _ensure_mandatory_params(action_idx: int, type: String):
	if not param_provider.is_valid() or type == "":
		return
	var params = param_provider.call(type)
	for p in params:
		if p.get("mandatory", false):
			if not _actions[action_idx].has(p["name"]):
				_actions[action_idx][p["name"]] = ""
