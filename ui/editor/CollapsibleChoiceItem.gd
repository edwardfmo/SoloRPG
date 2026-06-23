class_name CollapsibleChoiceItem
extends VBoxContainer

signal toggle_collapsed(idx: int, collapsed: bool)
signal choice_id_changed(idx: int, new_id: String)
signal choice_text_changed(idx: int, new_text: String)

@export var _header_button: Button
@export var _margin: MarginContainer
@export var _content: VBoxContainer
@export var _id_field: LineEdit
@export var _text_field: LineEdit
@export var _next_field: LineEdit
@export var _cond_label: Label
@export var _act_label: Label

var _collapsed: bool = true
var _idx: int = 0
var _choice_data: Dictionary = {}


func init_data(idx: int, choice: Dictionary, collapsed: bool = true):
	_idx = idx
	_choice_data = choice
	_collapsed = collapsed


func _ready():
	_header_button.pressed.connect(_on_toggle)
	_margin.visible = not _collapsed

	var id = _choice_data.get("id", "")
	var next_id = _choice_data.get("next", "")
	_update_header(id, next_id)

	_id_field.text = id
	_text_field.text = _choice_data.get("text", "")
	_next_field.text = next_id if next_id != "" else "Self"

	_id_field.text_changed.connect(_on_id_changed)
	_text_field.text_changed.connect(_on_text_changed)


func get_content_container() -> VBoxContainer:
	return _content


func get_conditions_insert_point() -> Control:
	return _cond_label


func get_actions_insert_point() -> Control:
	return _act_label


func _on_id_changed(new_text: String):
	_choice_data["id"] = new_text
	var next_id = _choice_data.get("next", "")
	_update_header(new_text, next_id)
	choice_id_changed.emit(_idx, new_text)


func _on_text_changed(new_text: String):
	_choice_data["text"] = new_text
	choice_text_changed.emit(_idx, new_text)


func _on_toggle():
	_collapsed = not _collapsed
	_margin.visible = not _collapsed
	var id = _choice_data.get("id", "")
	var next_id = _choice_data.get("next", "")
	_update_header(id, next_id)
	toggle_collapsed.emit(_idx, _collapsed)


func _update_header(id: String, next_id: String):
	var prefix = "▶ " if _collapsed else "▼ "
	var target = next_id if next_id != "" else "Self"
	_header_button.text = prefix + id + " -> " + target


func update_next(next_id: String):
	_choice_data["next"] = next_id
	_next_field.text = next_id if next_id != "" else "Self"
	var id = _choice_data.get("id", "")
	_update_header(id, next_id)
