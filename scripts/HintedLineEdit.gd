## A LineEdit with floating autocomplete dropdown.
## Set `hints` to provide autocomplete suggestions.
class_name HintedLineEdit
extends LineEdit

signal hint_selected(value: String)

## Array of strings to match against as the user types.
var hints: Array[String] = []

## If set, hints only show when text starts with this prefix.
var hint_prefix: String = ""

var _dropdown: ItemList


func _ready():
	_dropdown = ItemList.new()
	_dropdown.visible = false
	_dropdown.custom_minimum_size = Vector2(200, 80)
	_dropdown.max_text_lines = 1
	_dropdown.focus_mode = Control.FOCUS_NONE
	_dropdown.mouse_filter = Control.MOUSE_FILTER_STOP
	_dropdown.z_index = 100
	_dropdown.top_level = true
	add_child(_dropdown)

	text_changed.connect(_on_text_changed)
	focus_exited.connect(_on_focus_exited)
	_dropdown.item_clicked.connect(_on_item_clicked)


func _on_text_changed(_new_text: String):
	_update_dropdown()


func _on_focus_exited():
	var dropdown_ref = weakref(_dropdown)
	get_tree().create_timer(0.15).timeout.connect(func():
		var d = dropdown_ref.get_ref()
		if d:
			d.visible = false)


func _on_item_clicked(index: int, _at_pos: Vector2, _mouse_btn: int):
	var selected_text = _dropdown.get_item_text(index)
	text = selected_text
	text_changed.emit(selected_text)
	hint_selected.emit(selected_text)
	_dropdown.visible = false
	grab_focus()
	caret_column = selected_text.length()


func _update_dropdown():
	_dropdown.clear()
	var query = text.to_lower()
	if query == "":
		_dropdown.visible = false
		return
	if hint_prefix != "" and not text.begins_with(hint_prefix):
		_dropdown.visible = false
		return
	var matches: Array[String] = []
	for h in hints:
		if h.to_lower().contains(query):
			matches.append(h)
	if matches.is_empty():
		_dropdown.visible = false
		return
	for m in matches:
		_dropdown.add_item(m)
	_dropdown.visible = true
	_position_dropdown()


func _position_dropdown():
	var pos = get_global_position() + Vector2(0, size.y)
	_dropdown.global_position = pos
	_dropdown.size = Vector2(size.x, _dropdown.custom_minimum_size.y)
