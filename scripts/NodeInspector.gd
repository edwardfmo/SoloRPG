extends ScrollContainer

@export var id_edit: LineEdit
@export var text_edit: TextEdit
@export var image_edit: LineEdit
@export var on_enter_container: VBoxContainer
@export var choices_container: VBoxContainer
@export var add_choice_button: Button

var selected_node: StoryNode = null
var _expanded_choices: Array = []
var _on_enter_editor: VBoxContainer = null

## Published action types for on_enter autocomplete
var available_actions: Array[String] = []
## Published condition types for choice conditions autocomplete
var available_conditions: Array[String] = []
## Reference to ModAPI for param schemas
var api: ModAPI = null


func _ready():
	add_choice_button.pressed.connect(_on_add_choice)


func load_node(node: StoryNode):
	selected_node = node
	_expanded_choices.clear()
	id_edit.text = node.data["id"]
	text_edit.text = node.data["text"]
	image_edit.text = node.data["image"]
	visible = true
	rebuild_on_enter_list()
	rebuild_choices_list()


func clear():
	selected_node = null
	visible = false


func _on_id_changed(new_text):
	if selected_node:
		selected_node.id = new_text


func _on_text_changed():
	if selected_node:
		selected_node.data["text"] = text_edit.text


func _on_image_changed(new_text):
	if selected_node:
		selected_node.data["image"] = new_text


func rebuild_on_enter_list():
	# Remove old editor
	if _on_enter_editor:
		on_enter_container.remove_child(_on_enter_editor)
		_on_enter_editor.queue_free()
		_on_enter_editor = null

	if not selected_node:
		return

	if not selected_node.data.has("on_enter"):
		selected_node.data["on_enter"] = []

	_on_enter_editor = ActionListEditor.new()
	_on_enter_editor.available_types = available_actions
	if api:
		_on_enter_editor.param_provider = api.get_params_for_type
	on_enter_container.add_child(_on_enter_editor)
	_on_enter_editor.set_actions(selected_node.data["on_enter"])


func _on_add_choice():
	if not selected_node:
		return

	var choice_id = _generate_unique_choice_id(selected_node)
	selected_node.data["choices"].append({
		"id": choice_id,
		"text": choice_id,
		"next": "",
		"conditions": []
	})

	selected_node.rebuild_ports()
	rebuild_choices_list()


func _generate_unique_choice_id(node: StoryNode) -> String:
	var base = "choice"
	var id = base
	var i = 1
	var existing_ids = []
	for choice in node.data["choices"]:
		existing_ids.append(choice.get("id", ""))
	while id in existing_ids:
		id = base + "_" + str(i)
		i += 1
	return id


func rebuild_choices_list(expand_idx: int = -1):
	# Save expanded state before clearing
	var prev_expanded = _expanded_choices.duplicate()
	if expand_idx >= 0 and expand_idx not in prev_expanded:
		prev_expanded.append(expand_idx)
	_expanded_choices.clear()

	# Clear existing
	for child in choices_container.get_children():
		child.queue_free()

	if not selected_node:
		return

	for i in selected_node.data["choices"].size():
		var choice = selected_node.data["choices"][i]
		var row = VBoxContainer.new()
		var idx = i

		# Collapsed header button
		var next_id = choice.get("next", "")
		var header_text = choice.get("id", "") + " -> " + (next_id if next_id != "" else "Self")
		var header = Button.new()
		header.text = header_text
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		row.add_child(header)

		# Expanded details container (restore previous state)
		var details = VBoxContainer.new()
		details.visible = idx in prev_expanded
		if details.visible:
			_expanded_choices.append(idx)
		header.pressed.connect(func():
			details.visible = not details.visible
			if details.visible:
				if idx not in _expanded_choices:
					_expanded_choices.append(idx)
			else:
				_expanded_choices.erase(idx))

		# Choice ID row
		var id_row = HBoxContainer.new()
		var id_label = Label.new()
		id_label.text = "ID"
		id_label.add_theme_font_size_override("font_size", 11)
		var id_field = LineEdit.new()
		id_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_field.text = choice.get("id", "")
		id_field.text_changed.connect(func(new_text):
			selected_node.data["choices"][idx]["id"] = new_text
			var n = selected_node.data["choices"][idx].get("next", "")
			header.text = new_text + " -> " + (n if n != "" else "Self"))
		id_row.add_child(id_label)
		id_row.add_child(id_field)
		details.add_child(id_row)

		# Choice Text row
		var text_row = HBoxContainer.new()
		var text_label = Label.new()
		text_label.text = "Text"
		text_label.add_theme_font_size_override("font_size", 11)
		var text_field = LineEdit.new()
		text_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_field.text = choice.get("text", "")
		text_field.text_changed.connect(func(new_text):
			selected_node.data["choices"][idx]["text"] = new_text
			selected_node.rebuild_ports())
		text_row.add_child(text_label)
		text_row.add_child(text_field)
		details.add_child(text_row)

		# Next node row (read-only)
		var next_row = HBoxContainer.new()
		var next_label = Label.new()
		next_label.text = "Next"
		next_label.add_theme_font_size_override("font_size", 11)
		var next_field = LineEdit.new()
		next_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_field.text = choice.get("next", "") if choice.get("next", "") != "" else "Self"
		next_field.editable = false
		next_row.add_child(next_label)
		next_row.add_child(next_field)
		details.add_child(next_row)

		# Conditions section using ActionListEditor
		if not choice.has("conditions"):
			choice["conditions"] = []

		var cond_label = Label.new()
		cond_label.text = "Conditions"
		cond_label.add_theme_font_size_override("font_size", 11)
		details.add_child(cond_label)

		var cond_editor = ActionListEditor.new()
		cond_editor.available_types = available_conditions
		if api:
			cond_editor.param_provider = api.get_params_for_type
		cond_editor.set_actions(choice["conditions"])
		details.add_child(cond_editor)

		# Actions section using ActionListEditor
		if not choice.has("actions"):
			choice["actions"] = []

		var act_label = Label.new()
		act_label.text = "Actions"
		act_label.add_theme_font_size_override("font_size", 11)
		details.add_child(act_label)

		var act_editor = ActionListEditor.new()
		act_editor.available_types = available_actions
		if api:
			act_editor.param_provider = api.get_params_for_type
		act_editor.set_actions(choice["actions"])
		details.add_child(act_editor)

		details.add_child(HSeparator.new())
		row.add_child(details)

		# Separator
		var sep = HSeparator.new()
		row.add_child(sep)

		choices_container.add_child(row)
