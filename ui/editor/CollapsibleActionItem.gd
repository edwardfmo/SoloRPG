class_name CollapsibleActionItem
extends VBoxContainer

signal toggle_collapsed(idx: int, collapsed: bool)

@export var _header_button: Button
@export var _margin: MarginContainer
@export var _content: VBoxContainer

var _collapsed: bool = true
var _idx: int = 0
var _type_name: String = ""


func init_data(idx: int, type_name: String, collapsed: bool = true):
	_idx = idx
	_type_name = type_name
	_collapsed = collapsed


func _ready():
	_header_button.pressed.connect(_on_toggle)
	_update_header(_type_name)
	_margin.visible = not _collapsed


func get_content_container() -> VBoxContainer:
	return _content


func update_label(type_name: String):
	_update_header(type_name)


func set_collapsed(collapsed: bool):
	_collapsed = collapsed
	_margin.visible = not _collapsed
	_update_header(_get_current_name())


func _on_toggle():
	_collapsed = not _collapsed
	_margin.visible = not _collapsed
	_update_header(_get_current_name())
	toggle_collapsed.emit(_idx, _collapsed)


func _update_header(type_name: String):
	var prefix = "▶ " if _collapsed else "▼ "
	var label = type_name if type_name != "" else "(empty)"
	_header_button.text = prefix + label


func _get_current_name() -> String:
	# Extract from button text, stripping the prefix
	var text = _header_button.text
	if text.begins_with("▶ ") or text.begins_with("▼ "):
		return text.substr(2)
	return text
