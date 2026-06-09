extends Control

signal choice_selected(choice_data)

@export var image: TextureRect
@export var text: Label
@export var choices_container: VBoxContainer
@export var stats: Label


func display_node(node: Dictionary, module, context):
	# TEXT
	text.text = node.get("text", "")

	# IMAGE
	var path = node.get("image", "")
	if path != "":
		image.texture = load(path)
		image.visible = true
	else:
		image.visible = false

	# STATS
	stats.text = "HP: %s" % context.get("hp", 0)

	# CHOICES
	_build_choices(node, module, context)


func _build_choices(node, module, context):
	for c in choices_container.get_children():
		c.queue_free()

	for choice in node.get("choices", []):
		var btn = Button.new()
		btn.text = choice.get("text", "")

		var enabled = module.are_conditions_met(choice.get("conditions", []), context)
		btn.disabled = not enabled

		if btn.disabled:
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(func():
			if enabled:
				choice_selected.emit(choice)
		)

		choices_container.add_child(btn)
