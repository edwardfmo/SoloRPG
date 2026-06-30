extends VBoxContainer

## Editor panel for a single feature group item inside a class/species/background.
## Rendered as a custom item_schema panel by DNDSystem.

@export var _feature_name_edit: LineEdit
@export var _level_spin: SpinBox
@export var _choose_spin: SpinBox
@export var _entries_container: VBoxContainer
@export var _add_entry_btn: Button

var _item: Dictionary
var _on_changed: Callable
var _get_ref_hints: Callable
var _resolve_ref_display: Callable
var _editable: bool = true
var _ref_types: Array = ["character_feature", "skill", "weapon", "armor", "group"]


func setup(item: Dictionary, context: Dictionary):
	_item = item
	_on_changed = context.get("on_changed", Callable())
	_get_ref_hints = context.get("get_ref_hints", Callable())
	_resolve_ref_display = context.get("resolve_ref_display", Callable())
	_editable = context.get("editable", true)

	# Feature name
	_feature_name_edit.text = _item.get("feature_name", "")
	_feature_name_edit.editable = _editable
	if _editable:
		_feature_name_edit.text_submitted.connect(func(t): _set_feature_name(t))
		_feature_name_edit.focus_exited.connect(func(): _set_feature_name(_feature_name_edit.text))

	# Level
	_level_spin.value = _item.get("level", 1)
	_level_spin.editable = _editable
	if _editable:
		_level_spin.value_changed.connect(func(v):
			_item["level"] = int(v)
			_notify_changed())

	# Number to choose
	_choose_spin.value = _item.get("number_to_choose", 0)
	_choose_spin.editable = _editable
	if _editable:
		_choose_spin.value_changed.connect(func(v):
			if int(v) == 0:
				_item.erase("number_to_choose")
			else:
				_item["number_to_choose"] = int(v)
			_notify_changed())

	# Entries
	_rebuild_entries()

	# Add button
	_add_entry_btn.visible = _editable
	if _editable:
		_add_entry_btn.pressed.connect(_on_add_entry)


func _set_feature_name(text: String):
	var val = text.strip_edges()
	if val == "":
		_item.erase("feature_name")
	else:
		_item["feature_name"] = val
	_notify_changed()


func _rebuild_entries():
	for child in _entries_container.get_children():
		child.queue_free()

	var entries: Array = _item.get("entries", [])
	var hints: Array[String] = []
	if _get_ref_hints.is_valid():
		hints = _get_ref_hints.call(_ref_types)

	for i in entries.size():
		var row = HBoxContainer.new()

		# Display label (resolved name)
		var display = Label.new()
		display.custom_minimum_size = Vector2(150, 0)
		var ref_str = str(entries[i])
		if _resolve_ref_display.is_valid() and ref_str.begins_with("@"):
			display.text = _resolve_ref_display.call(ref_str)
		else:
			display.text = ref_str
		row.add_child(display)

		if _editable:
			# Edit field (hinted)
			var hinted = HintedLineEdit.new()
			hinted.hints = hints
			hinted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hinted.text = ref_str
			hinted.editable = true
			var idx = i
			hinted.text_submitted.connect(func(new_text: String):
				_update_entry(idx, new_text))
			hinted.hint_selected.connect(func(value: String):
				_update_entry(idx, value))
			row.add_child(hinted)

			# Remove button
			var rm_btn = Button.new()
			rm_btn.text = "X"
			rm_btn.custom_minimum_size = Vector2(24, 0)
			rm_btn.pressed.connect(func():
				entries.remove_at(idx)
				_item["entries"] = entries
				_notify_changed()
				_rebuild_entries())
			row.add_child(rm_btn)

		_entries_container.add_child(row)


func _update_entry(idx: int, value: String):
	var entries: Array = _item.get("entries", [])
	var val = value.strip_edges()
	if val == "":
		entries.remove_at(idx)
	else:
		entries[idx] = val
	_item["entries"] = entries
	_notify_changed()
	_rebuild_entries()


func _on_add_entry():
	var entries: Array = _item.get("entries", [])
	entries.append("")
	_item["entries"] = entries
	_rebuild_entries()


func _notify_changed():
	if _on_changed.is_valid():
		_on_changed.call()
