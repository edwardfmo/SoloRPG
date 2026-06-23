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
var _choice_scene: PackedScene = preload("res://ui/editor/CollapsibleChoiceItem.tscn")
var _action_list_scene: PackedScene = preload("res://ui/editor/ActionListEditor.tscn")
var _condition_list_scene: PackedScene = preload("res://ui/editor/ConditionListEditor.tscn")

## Published action types for on_enter autocomplete
var available_actions: Array[String] = []
## Published condition types for choice conditions autocomplete
var available_conditions: Array[String] = []
## Reference to ModAPI for param schemas
var api: ModAPI = null


func _get_entry_hints() -> Array[String]:
	var result: Array[String] = []
	if api == null:
		return result
	for tmpl_id in api._entries:
		for namespaced_id in api._entries[tmpl_id]:
			result.append("@" + namespaced_id)
	return result


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

	_on_enter_editor = _action_list_scene.instantiate()
	_on_enter_editor.available_types = available_actions
	if api:
		_on_enter_editor.param_provider = api.get_params_for_type
		_on_enter_editor.entry_hints = _get_entry_hints()
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
		var idx = i
		var is_expanded = idx in prev_expanded

		var item: CollapsibleChoiceItem = _choice_scene.instantiate()
		item.init_data(idx, choice, not is_expanded)
		item.toggle_collapsed.connect(func(ci, collapsed):
			if not collapsed:
				if ci not in _expanded_choices:
					_expanded_choices.append(ci)
			else:
				_expanded_choices.erase(ci))
		item.choice_text_changed.connect(func(_ci, _new_text):
			selected_node.rebuild_ports())
		choices_container.add_child(item)

		if is_expanded:
			_expanded_choices.append(idx)

		# Conditions section
		if not choice.has("conditions"):
			choice["conditions"] = []

		var cond_editor = _condition_list_scene.instantiate()
		cond_editor.available_types = available_conditions
		if api:
			cond_editor.param_provider = api.get_params_for_type
			cond_editor.entry_hints = _get_entry_hints()
		cond_editor.set_actions(choice["conditions"])
		var content = item.get_content_container()
		content.add_child(cond_editor)
		content.move_child(cond_editor, item.get_conditions_insert_point().get_index() + 1)

		# Actions section
		if not choice.has("actions"):
			choice["actions"] = []

		var act_editor = _action_list_scene.instantiate()
		act_editor.available_types = available_actions
		if api:
			act_editor.param_provider = api.get_params_for_type
			act_editor.entry_hints = _get_entry_hints()
		act_editor.set_actions(choice["actions"])
		content.add_child(act_editor)
		content.move_child(act_editor, item.get_actions_insert_point().get_index() + 1)
