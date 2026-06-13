class_name StoryNode
extends GraphNode

var data = {
	"id": "",
	"text": "",
	"image": "",
	"on_enter": [],
	"choices": [],
	"offset": []
}

var offset: Vector2

signal id_changed(old_id, new_id)

var _id: String = ""

var id: String:
	set(value):
		if value == _id:
			return

		var old = _id
		_id = value

		title = value
		data["id"] = value

		id_changed.emit(old, value)

	get:
		return id

func _ready():
	title = "Node"
	custom_minimum_size = Vector2(200, 150)
	
	add_child(Control.new())
	set_slot(0, true, 0, Color.GREEN, false, 0, Color.GREEN)

func rebuild_ports():
	clear_all_slots()
	for child in get_children():
		child.queue_free()

	if data["choices"].size() == 0:
		add_child(Control.new())
		set_slot(0, true, 0, Color.GREEN, false, 0, Color.GREEN)
	else:
		for i in data["choices"].size():
			# 1. Create a row UI element
			var row = HBoxContainer.new()

			var label = Label.new()
			label.text = data["choices"][i]["text"]

			row.add_child(label)
			add_child(row)

			# 2. Attach slot to THIS row index
			set_slot(
				i,
				i == 0, 0, Color.GREEN,
				true, 0, Color.GREEN
			)
