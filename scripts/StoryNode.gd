class_name StoryNode
extends GraphNode

var data = {
	"id": "",
	"text": "",
	"image": "",
	"on_enter": [],
	"choices": []
}

var offset: Vector2

func _ready():
	title = "Node"
	custom_minimum_size = Vector2(200, 150)
	set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)


func rebuild_ports():
	clear_all_slots()

	for i in data["choices"].size():
		# output slot per choice
		set_slot(i, false, 0, Color.WHITE, true, 0, Color.GREEN)
