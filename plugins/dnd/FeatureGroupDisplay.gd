class_name FeatureGroupDisplay
extends VBoxContainer

signal selection_changed

@export var _header: HBoxContainer
@export var _feature_name_label: Label
@export var _counter_label: Label
@export var _list_container: VBoxContainer

var _refs: Array = []
var _max_select: int = 0
var _checkboxes: Array = []


func setup(feature_name: String, refs: Array, names: Array, max_select: int):
	_refs = refs
	_max_select = max_select
	# Header visibility
	var auto_all := max_select >= refs.size()
	_feature_name_label.text = feature_name
	_feature_name_label.visible = feature_name != ""
	_counter_label.visible = not auto_all
	_header.visible = true
	# Create checkboxes
	for child in _list_container.get_children():
		child.queue_free()
	_checkboxes.clear()
	for i in refs.size():
		var cb = CheckBox.new()
		cb.text = names[i] if i < names.size() else ""
		_list_container.add_child(cb)
		_checkboxes.append(cb)
		if auto_all:
			cb.button_pressed = true
			cb.disabled = true
		elif i < max_select:
			cb.button_pressed = true
		if not auto_all:
			cb.toggled.connect(func(_p): _on_toggled())
	_update_counter()


func get_selected_refs() -> Array:
	var result := []
	for i in _checkboxes.size():
		if _checkboxes[i].button_pressed and i < _refs.size():
			result.append(_refs[i])
	return result


func _on_toggled():
	_update_counter()
	selection_changed.emit()


func _update_counter():
	if not _counter_label.visible:
		return
	var selected_count := 0
	for cb in _checkboxes:
		if cb.button_pressed:
			selected_count += 1
	_counter_label.text = str(selected_count) + " / " + str(_max_select)
	if selected_count == _max_select:
		_counter_label.modulate = Color(0.3, 1.0, 0.3)
	elif selected_count > _max_select:
		_counter_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		_counter_label.modulate = Color(1.0, 1.0, 1.0)
