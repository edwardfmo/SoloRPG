extends Control

signal close_pressed

@export var graph: GraphEdit
@export var module_id_edit: LineEdit
@export var module_name_edit: LineEdit
@export var module_version_edit: LineEdit
@export var module_author_edit: LineEdit

@export var node_inspector: ScrollContainer

@export var save_button: Button
@export var save_as_button: Button

@export var save_file_dialog: FileDialog
@export var open_file_dialog: FileDialog

var nodes = []
var node_map = {}        # name → node
var id_map = {}          # id → node
var selected_node: StoryNode = null
var _last_export_path: String = ""
var start_node_gn: GraphNode = null
var frames = []          # GraphFrame instances

func _ready() -> void:
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.delete_nodes_request.connect(_on_delete_nodes_request)
	node_inspector.visible = false
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_clear_editor()
		module_id_edit.text = ""
		module_name_edit.text = ""
		module_version_edit.text = ""
		module_author_edit.text = ""
		_last_export_path = ""
		_set_module_controls_enabled(false)


func _set_module_controls_enabled(enabled: bool):
	graph.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	graph.modulate.a = 1.0 if enabled else 0.3
	module_id_edit.editable = enabled
	module_name_edit.editable = enabled
	module_version_edit.editable = enabled
	module_author_edit.editable = enabled
	save_button.disabled = not enabled
	save_as_button.disabled = not enabled

func _input(event):
	if graph.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			create_node_at_mouse()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_G and event.ctrl_pressed:
			create_frame_at_mouse()

func create_node_at_mouse():
	var node = StoryNode.new()

	node.name = "node_" + str(nodes.size())

	# Convert screen → graph space
	node.position_offset = graph.get_local_mouse_position() + graph.scroll_offset
	node.data["offset"] = [node.position_offset.x, node.position_offset.y]

	graph.add_child(node)
	nodes.append(node)
	
	node_map[node.name] = node

	# assign unique id
	var new_id = _generate_unique_id("node")
	node.id = new_id

	id_map[new_id] = node

	# listen to id changes
	node.id_changed.connect(_on_node_id_changed.bind(node))

	# update data offset when dragged
	node.dragged.connect(func(_from, to):
		node.data["offset"] = [to.x, to.y])

	node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			selected_node = node
			_load_into_inspector(node))

	# Auto-attach to frame if dropped inside one
	node.dragged.connect(func(_from, _to):
		_auto_attach_to_frame(node))
	_auto_attach_to_frame(node)

func _generate_unique_id(base: String) -> String:
	var id = base
	var i = 1

	while id_map.has(id):
		id = base + "_" + str(i)
		i += 1

	return id


func create_frame_at_mouse():
	var frame = GraphFrame.new()
	frame.name = "frame_" + str(frames.size())
	frame.title = "Group"
	frame.tint_color_enabled = true
	frame.autoshrink_enabled = true
	frame.position_offset = graph.get_local_mouse_position() + graph.scroll_offset
	frame.custom_minimum_size = Vector2(300, 200)
	graph.add_child(frame)
	frames.append(frame)
	_setup_frame_rename(frame)


func _setup_frame_rename(frame: GraphFrame):
	var titlebar = frame.get_titlebar_hbox()
	titlebar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.double_click:
			# Find the title label
			var label: Label = null
			for child in titlebar.get_children():
				if child is Label:
					label = child
					break
			if not label:
				return
			# Replace label with LineEdit
			label.visible = false
			var edit = LineEdit.new()
			edit.text = frame.title
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			titlebar.add_child(edit)
			edit.grab_focus()
			edit.select_all()
			var _commit = func():
				frame.title = edit.text
				label.visible = true
				edit.queue_free()
			edit.text_submitted.connect(func(_t): _commit.call())
			edit.focus_exited.connect(_commit))


func _auto_attach_to_frame(node: GraphNode):
	var node_rect = Rect2(node.position_offset, node.size)
	var best_frame: GraphFrame = null

	for frame in frames:
		var frame_rect = Rect2(frame.position_offset, frame.size)
		if frame_rect.encloses(node_rect):
			best_frame = frame

	# Detach from current frame if outside
	var current_frame = graph.get_element_frame(node.name)
	if current_frame and current_frame != best_frame:
		graph.detach_graph_element_from_frame(node.name)

	# Attach to new frame
	if best_frame and graph.get_element_frame(node.name) != best_frame:
		graph.attach_graph_element_to_frame(node.name, best_frame.name)


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
	node_inspector.load_node(node)

func _on_connection_request(from, from_port, to, to_port):
	# Remove existing connections from this port (max 1 connection per output)
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
	node_inspector.rebuild_choices_list()

func _on_disconnection_request(from, from_port, to, to_port):
	var from_node = graph.get_node(NodePath(from))

	if from_node != start_node_gn:
		from_node.data["choices"][from_port]["next"] = ""

	graph.disconnect_node(from, from_port, to, to_port)
	node_inspector.rebuild_choices_list()

func export_module(path: String):
	# Determine start node from Start connector
	var start_id = ""
	for conn in graph.get_connection_list():
		if conn["from_node"] == start_node_gn.name:
			var target = graph.get_node(NodePath(conn["to_node"]))
			if target is StoryNode:
				start_id = target.data["id"]
			break

	var module = {
		"id": module_id_edit.text if module_id_edit.text != "" else "editor_module",
		"name": module_name_edit.text,
		"version": module_version_edit.text,
		"author": module_author_edit.text,
		"start_node": start_id,
		"nodes": {}
	}

	for n in nodes:
		module["nodes"][n.data["id"]] = n.data

	# Serialize frames
	var frames_data = []
	for frame in frames:
		var frame_info = {
			"title": frame.title,
			"offset": [frame.position_offset.x, frame.position_offset.y],
			"size": [frame.size.x, frame.size.y],
			"attached_nodes": []
		}
		for node in nodes:
			if graph.get_element_frame(node.name) == frame:
				frame_info["attached_nodes"].append(node.data["id"])
		frames_data.append(frame_info)
	if frames_data.size() > 0:
		module["frames"] = frames_data

	var json = JSON.stringify(module, "\t")

	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json)

	print("Exported to: " + path)

func _on_save_pressed():
	if _last_export_path != "":
		export_module(_last_export_path)
	else:
		save_file_dialog.popup_centered()

func _on_save_as_pressed():
	save_file_dialog.popup_centered()

func _on_file_selected(path: String):
	_last_export_path = path
	export_module(path)

func _on_close_pressed():
	close_pressed.emit()

func _on_new_pressed():
	_clear_editor()
	module_id_edit.text = ""
	module_name_edit.text = ""
	module_version_edit.text = ""
	module_author_edit.text = ""
	_last_export_path = ""
	_set_module_controls_enabled(true)
	_create_start_node()

func _on_open_pressed():
	open_file_dialog.popup_centered()

func _on_open_file_selected(path: String):
	load_module(path)

func load_module(path: String):
	var json_text = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json_text)
	if data == null:
		print("Failed to parse module file.")
		return

	# Clear existing state
	_clear_editor()
	_set_module_controls_enabled(true)

	# Set module ID
	module_id_edit.text = data.get("id", "")
	module_name_edit.text = data.get("name", "")
	module_version_edit.text = data.get("version", "")
	module_author_edit.text = data.get("author", "")
	_last_export_path = path

	# Create nodes
	var node_data_map = data.get("nodes", {})
	for node_id in node_data_map:
		var nd = node_data_map[node_id]
		var node = StoryNode.new()
		node.name = "node_" + str(nodes.size())

		# Set position from offset
		var offset = nd.get("offset", [0, 0])
		if (offset.size() == 2):
			node.position_offset = Vector2(offset[0], offset[1])

		graph.add_child(node)
		nodes.append(node)
		node_map[node.name] = node

		# Set id
		node.id = node_id
		id_map[node_id] = node

		# Set data fields
		node.data["text"] = nd.get("text", "")
		node.data["image"] = nd.get("image", "")
		node.data["on_enter"] = nd.get("on_enter", [])
		node.data["choices"] = nd.get("choices", [])
		node.data["offset"] = offset

		node.rebuild_ports()

		# Connect signals
		node.id_changed.connect(_on_node_id_changed.bind(node))
		node.dragged.connect(func(_from, to):
			node.data["offset"] = [to.x, to.y]
			_auto_attach_to_frame(node))
		node.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				selected_node = node
				_load_into_inspector(node))

	# Restore connections
	for node in nodes:
		for i in node.data["choices"].size():
			var next_id = node.data["choices"][i].get("next", "")
			if next_id != "" and id_map.has(next_id):
				var target = id_map[next_id]
				graph.connect_node(node.name, i, target.name, 0)

	# Select start node
	var start_id = data.get("start_node", "")
	if id_map.has(start_id):
		selected_node = id_map[start_id]
		_load_into_inspector(selected_node)

	# Create the Start connector and link it to the start node
	_create_start_node()
	if id_map.has(start_id):
		var target = id_map[start_id]
		graph.connect_node(start_node_gn.name, 0, target.name, 0)

	# Restore frames
	var frames_data = data.get("frames", [])
	for fd in frames_data:
		var frame = GraphFrame.new()
		frame.name = "frame_" + str(frames.size())
		frame.title = fd.get("title", "Group")
		frame.tint_color_enabled = true
		frame.autoshrink_enabled = true
		var f_offset = fd.get("offset", [0, 0])
		frame.position_offset = Vector2(f_offset[0], f_offset[1])
		var f_size = fd.get("size", [300, 200])
		frame.custom_minimum_size = Vector2(f_size[0], f_size[1])
		frame.size = Vector2(f_size[0], f_size[1])
		graph.add_child(frame)
		frames.append(frame)
		_setup_frame_rename(frame)
		for attached_id in fd.get("attached_nodes", []):
			if id_map.has(attached_id):
				var attached_node = id_map[attached_id]
				graph.attach_graph_element_to_frame(attached_node.name, frame.name)

func _clear_editor():
	# Disconnect all graph connections
	graph.clear_connections()

	# Remove start node
	if start_node_gn:
		graph.remove_child(start_node_gn)
		start_node_gn.queue_free()
		start_node_gn = null

	# Remove all node children
	for node in nodes:
		graph.remove_child(node)
		node.queue_free()

	nodes.clear()
	node_map.clear()
	id_map.clear()
	selected_node = null
	node_inspector.clear()

	# Remove frames
	for frame in frames:
		graph.remove_child(frame)
		frame.queue_free()
	frames.clear()


func _create_start_node():
	start_node_gn = GraphNode.new()
	start_node_gn.name = "__start__"
	start_node_gn.title = "Start"
	start_node_gn.position_offset = Vector2(0, 0)
	start_node_gn.custom_minimum_size = Vector2(100, 60)
	start_node_gn.add_child(Control.new())
	start_node_gn.set_slot(0, false, 0, Color.GREEN, true, 0, Color.GREEN)
	graph.add_child(start_node_gn)


func _on_delete_nodes_request(node_names: Array[StringName]):
	for node_name in node_names:
		if str(node_name) == "__start__":
			continue
		var node = graph.get_node(NodePath(str(node_name)))
		if node is GraphFrame:
			frames.erase(node)
			graph.remove_child(node)
			node.queue_free()
		elif node is StoryNode:
			# Remove connections involving this node
			for conn in graph.get_connection_list():
				if conn["from_node"] == node_name or conn["to_node"] == node_name:
					graph.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
			nodes.erase(node)
			node_map.erase(node.name)
			id_map.erase(node.data["id"])
			graph.remove_child(node)
			node.queue_free()
