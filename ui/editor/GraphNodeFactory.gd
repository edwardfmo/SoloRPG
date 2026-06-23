class_name GraphNodeFactory
extends RefCounted

var graph: GraphEdit
var nodes: Array = []
var node_map: Dictionary = {}
var id_map: Dictionary = {}
var start_node_gn: GraphNode = null

var _frame_manager: GraphFrameManager = null
var _start_node_scene = preload("res://ui/editor/StartNode.tscn")

signal node_selected(node: StoryNode)


func setup(p_graph: GraphEdit, p_nodes: Array, p_node_map: Dictionary, p_id_map: Dictionary, p_frame_manager: GraphFrameManager):
	graph = p_graph
	nodes = p_nodes
	node_map = p_node_map
	id_map = p_id_map
	_frame_manager = p_frame_manager


func create_node_at(pos: Vector2) -> StoryNode:
	var node = StoryNode.new()
	node.name = "node_" + str(nodes.size())
	node.position_offset = pos
	node.data["offset"] = [pos.x, pos.y]

	graph.add_child(node)
	nodes.append(node)
	node_map[node.name] = node

	var new_id = _generate_unique_id("node")
	node.id = new_id
	id_map[new_id] = node

	_wire_node_signals(node)
	_frame_manager.auto_attach_to_frame(node, pos)
	return node


func create_node_at_mouse() -> StoryNode:
	return create_node_at((graph.get_local_mouse_position() + graph.scroll_offset) / graph.zoom)


func create_node_from_data(node_id: String, nd: Dictionary) -> StoryNode:
	var node = StoryNode.new()
	node.name = "node_" + str(nodes.size())

	var offset = nd.get("offset", [0, 0])
	if offset.size() == 2:
		node.position_offset = Vector2(offset[0], offset[1])

	graph.add_child(node)
	nodes.append(node)
	node_map[node.name] = node

	node.id = node_id
	id_map[node_id] = node

	node.data["text"] = nd.get("text", "")
	node.data["image"] = nd.get("image", "")
	node.data["on_enter"] = nd.get("on_enter", [])
	node.data["choices"] = nd.get("choices", [])
	node.data["offset"] = offset

	node.rebuild_ports()
	_wire_node_signals(node)
	return node


func restore_connections():
	for node in nodes:
		for i in node.data["choices"].size():
			var next_id = node.data["choices"][i].get("next", "")
			if next_id != "" and id_map.has(next_id):
				var target = id_map[next_id]
				graph.connect_node(node.name, i, target.name, 0)


func create_start_node():
	start_node_gn = _start_node_scene.instantiate()
	start_node_gn.name = "__start__"
	start_node_gn.set_slot(0, false, 0, Color.GREEN, true, 0, Color.GREEN)
	graph.add_child(start_node_gn)


func connect_start_to(node_id: String):
	if id_map.has(node_id) and start_node_gn:
		var target = id_map[node_id]
		graph.connect_node(start_node_gn.name, 0, target.name, 0)


func delete_node(node: StoryNode):
	for conn in graph.get_connection_list():
		if conn["from_node"] == node.name or conn["to_node"] == node.name:
			graph.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	nodes.erase(node)
	node_map.erase(node.name)
	id_map.erase(node.data["id"])
	graph.remove_child(node)
	node.queue_free()


func clear_all():
	graph.clear_connections()

	if start_node_gn:
		graph.remove_child(start_node_gn)
		start_node_gn.queue_free()
		start_node_gn = null

	for node in nodes:
		graph.remove_child(node)
		node.queue_free()

	nodes.clear()
	node_map.clear()
	id_map.clear()


func handle_connection(from: StringName, from_port: int, to: StringName, to_port: int):
	# Remove existing connections from this port (max 1 per output)
	for conn in graph.get_connection_list():
		if conn["from_node"] == from and conn["from_port"] == from_port:
			graph.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
			var existing_from = graph.get_node(NodePath(conn["from_node"]))
			if existing_from != start_node_gn and existing_from is StoryNode:
				existing_from.data["choices"][conn["from_port"]]["next"] = ""

	var from_node = graph.get_node(NodePath(from))
	var to_node = graph.get_node(NodePath(to))

	if from_node != start_node_gn:
		from_node.data["choices"][from_port]["next"] = to_node.data["id"]

	graph.connect_node(from, from_port, to, to_port)


func handle_disconnection(from: StringName, from_port: int, to: StringName, to_port: int):
	var from_node = graph.get_node(NodePath(from))

	if from_node != start_node_gn:
		from_node.data["choices"][from_port]["next"] = ""

	graph.disconnect_node(from, from_port, to, to_port)


func _generate_unique_id(base: String) -> String:
	var id = base
	var i = 1
	while id_map.has(id):
		id = base + "_" + str(i)
		i += 1
	return id


func _wire_node_signals(node: StoryNode):
	node.id_changed.connect(_on_node_id_changed.bind(node))
	node.dragged.connect(func(_from, to):
		node.data["offset"] = [to.x, to.y]
		_frame_manager.auto_attach_to_frame(node))
	node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			node_selected.emit(node))


func _on_node_id_changed(old_id, new_id, node):
	if old_id != "":
		id_map.erase(old_id)

	if id_map.has(new_id):
		var fixed = _generate_unique_id(new_id)
		node.set_id(fixed)
		return

	id_map[new_id] = node
	_update_all_references(old_id, new_id)


func _update_all_references(old_id: String, new_id: String):
	if old_id == "":
		return
	for node in nodes:
		for choice in node.data.get("choices", []):
			if choice.get("next", "") == old_id:
				choice["next"] = new_id
