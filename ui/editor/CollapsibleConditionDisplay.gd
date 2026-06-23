## Collapsible display for a single condition entry.
## Adds OR-with-above and NOT toggles.
class_name CollapsibleConditionDisplay
extends CollapsibleAPIItemDisplay

var _show_or: bool = false


func setup(idx: int, action: Dictionary, config: Dictionary):
	super.setup(idx, action, config)
	_show_or = config.get("show_or", false)


func _build_content():
	# OR toggle (between condition rows)
	if _show_or:
		var or_btn = CheckButton.new()
		or_btn.text = "OR with above"
		or_btn.button_pressed = _action.get("or_above", false)
		or_btn.toggled.connect(func(pressed):
			if pressed:
				_action["or_above"] = true
			else:
				_action.erase("or_above")
			item_changed.emit())
		_content.add_child(or_btn)

	super._build_content()


func _configure_type_row(type_row: Node):
	var not_btn: CheckButton = type_row.get_node("NotToggle")
	not_btn.visible = true
	not_btn.button_pressed = _action.get("negate", false)
	not_btn.toggled.connect(func(pressed):
		if pressed:
			_action["negate"] = true
		else:
			_action.erase("negate")
		item_changed.emit())
