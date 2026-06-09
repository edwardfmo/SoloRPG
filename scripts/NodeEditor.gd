extends Control

@export var graph: GraphEdit

@export var id_edit: LineEdit
@export var text_edit: TextEdit
@export var image_edit: LineEdit

var nodes = []
var node_map = {}        # name → node
var id_map = {}          # id → node
var selected_node: StoryNode = null

func _ready() -> void:
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			create_node_at_mouse()

func create_node_at_mouse():
	var node = StoryNode.new()

	node.name = "node_" + str(nodes.size())

	# Convert screen → graph space
	node.offset = graph.get_local_mouse_position() + graph.scroll_offset

	graph.add_child(node)
	nodes.append(node)
	
	node_map[node.name] = node

	# assign unique id
	var new_id = _generate_unique_id("node")
	node.id = new_id

	id_map[new_id] = node

	# listen to id changes
	node.id_changed.connect(_on_node_id_changed.bind(node))
	
	node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			selected_node = node
			_load_into_inspector(node))

func _generate_unique_id(base: String) -> String:
	var id = base
	var i = 1

	while id_map.has(id):
		id = base + "_" + str(i)
		i += 1

	return id

func _on_node_id_changed(old_id, new_id, node):
	# Remove old
	if old_id != "":
		id_map.erase(old_id)

	# Enforce uniqueness
	if id_map.has(new_id):
		var fixed = _generate_unique_id(new_id)
		node.set_id(fixed)
		return

	# Register new
	id_map[new_id] = node

	_update_all_references(old_id, new_id)

func _update_all_references(old_id: String, new_id: String):
	if old_id == "":
		return

	for node in nodes:
		for choice in node.data.get("choices", []):
			if choice.get("next", "") == old_id:
				choice["next"] = new_id

func _load_into_inspector(node):
	id_edit.text = node.data["id"]
	text_edit.text = node.data["text"]
	image_edit.text = node.data["image"]

func _on_id_changed(new_text):
	if selected_node:
		selected_node.id = new_text

func _on_text_changed():
	if selected_node:
		selected_node.data["text"] = text_edit.text

func _on_image_changed(new_text):
	if selected_node:
		selected_node.data["image"] = new_text

func _on_add_choice():
	if not selected_node:
		return

	selected_node.data["choices"].append({
		"text": "New Choice",
		"next": ""
	})

	selected_node.rebuild_ports()
	
func _on_connection_request(from, from_port, to, to_port):
	var from_node = graph.get_node(NodePath(from))
	var to_node = graph.get_node(NodePath(to))

	from_node.data["choices"][from_port]["next"] = to_node.data["id"]

	graph.connect_node(from, from_port, to, to_port)

func _on_disconnection_request(from, from_port, to, to_port):
	var from_node = graph.get_node(NodePath(from))

	from_node.data["choices"][from_port]["next"] = ""

	graph.disconnect_node(from, from_port, to, to_port)

func export_module():
	var module = {
		"id": "editor_module",
		"start_node": nodes[0].data["id"],
		"nodes": {}
	}

	for n in nodes:
		module["nodes"][n.data["id"]] = n.data

	var json = JSON.stringify(module, "\t")

	var file = FileAccess.open("res://module.json", FileAccess.WRITE)
	file.store_string(json)

	print("Exported!")

func _on_export_pressed():
	export_module()
