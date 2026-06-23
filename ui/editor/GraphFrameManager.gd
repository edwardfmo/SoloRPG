class_name GraphFrameManager
extends RefCounted

var graph: GraphEdit
var frames: Array = []
var nodes: Array = []  # reference to NodeEditor's nodes array

var _attaching_frame: bool = false
var _drag_detach_set: Dictionary = {}
var _inline_edit_scene = preload("res://ui/editor/InlineRenameEdit.tscn")


func setup(p_graph: GraphEdit, p_nodes: Array, p_frames: Array):
	graph = p_graph
	nodes = p_nodes
	frames = p_frames


func create_frame_at(pos: Vector2):
	var frame = GraphFrame.new()
	frame.name = "frame_" + str(frames.size())
	frame.title = "Group"
	frame.tint_color_enabled = true
	frame.autoshrink_enabled = true
	frame.position_offset = pos
	frame.custom_minimum_size = Vector2(300, 200)
	graph.add_child(frame)
	frames.append(frame)
	_setup_frame_rename(frame)
	frame.dragged.connect(func(_from, _to):
		auto_attach_to_frame(frame))
	auto_attach_to_frame(frame, pos)


func create_frame_at_mouse():
	create_frame_at((graph.get_local_mouse_position() + graph.scroll_offset) / graph.zoom)


func detach_selected_elements():
	for node in nodes:
		if node.selected:
			var current_frame = graph.get_element_frame(node.name)
			if current_frame:
				_attaching_frame = true
				graph.detach_graph_element_from_frame(node.name)
				_attaching_frame = false
			_drag_detach_set[node.name] = true
	for frame in frames:
		if frame.selected:
			var current_frame = graph.get_element_frame(frame.name)
			if current_frame:
				_attaching_frame = true
				graph.detach_graph_element_from_frame(frame.name)
				_attaching_frame = false
			_drag_detach_set[frame.name] = true


func clear_drag_detach():
	_drag_detach_set.clear()


func auto_attach_to_frame(node: GraphElement, check_pos: Vector2 = Vector2.INF):
	if _attaching_frame:
		return

	if _drag_detach_set.has(node.name):
		return

	var mouse_pos = check_pos if check_pos != Vector2.INF else (graph.get_local_mouse_position() + graph.scroll_offset) / graph.zoom
	var best_frame: GraphFrame = null
	var best_area: float = INF

	for frame in frames:
		if frame == node:
			continue
		if node is GraphFrame and _is_descendant_frame(frame, node):
			continue
		var frame_rect = Rect2(frame.position_offset, frame.size)
		if frame_rect.has_point(mouse_pos):
			var area = frame_rect.get_area()
			if area < best_area:
				best_area = area
				best_frame = frame

	var current_frame = graph.get_element_frame(node.name)
	if current_frame and current_frame != best_frame:
		_attaching_frame = true
		graph.detach_graph_element_from_frame(node.name)
		_attaching_frame = false

	if best_frame and graph.get_element_frame(node.name) != best_frame:
		_attaching_frame = true
		graph.attach_graph_element_to_frame(node.name, best_frame.name)
		_attaching_frame = false


func delete_frame(frame: GraphFrame):
	var parent_frame = graph.get_element_frame(frame.name)
	for n in nodes:
		if graph.get_element_frame(n.name) == frame:
			graph.detach_graph_element_from_frame(n.name)
			if parent_frame:
				graph.attach_graph_element_to_frame(n.name, parent_frame.name)
	for f in frames:
		if f != frame and graph.get_element_frame(f.name) == frame:
			graph.detach_graph_element_from_frame(f.name)
			if parent_frame:
				graph.attach_graph_element_to_frame(f.name, parent_frame.name)
	frames.erase(frame)
	graph.remove_child(frame)
	frame.queue_free()


func clear_all():
	for frame in frames:
		graph.remove_child(frame)
		frame.queue_free()
	frames.clear()


func restore_frames(frames_data: Array, id_map: Dictionary):
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
		frame.dragged.connect(func(_from, _to):
			auto_attach_to_frame(frame))
		for attached_id in fd.get("attached_nodes", []):
			if id_map.has(attached_id):
				var attached_node = id_map[attached_id]
				graph.attach_graph_element_to_frame(attached_node.name, frame.name)
	# Restore nesting
	for i in frames_data.size():
		var fd = frames_data[i]
		var parent_idx = fd.get("parent_frame", -1)
		if parent_idx >= 0 and parent_idx < frames.size():
			graph.attach_graph_element_to_frame(frames[i].name, frames[parent_idx].name)


func serialize_frames() -> Array:
	var frames_data = []
	var frame_index_map = {}
	for i in frames.size():
		frame_index_map[frames[i]] = i
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
		var pf = graph.get_element_frame(frame.name)
		if pf and frame_index_map.has(pf):
			frame_info["parent_frame"] = frame_index_map[pf]
		frames_data.append(frame_info)
	return frames_data


func _is_descendant_frame(ancestor: GraphFrame, descendant: GraphFrame) -> bool:
	var current = graph.get_element_frame(ancestor.name)
	while current:
		if current == descendant:
			return true
		current = graph.get_element_frame(current.name)
	return false


func _setup_frame_rename(frame: GraphFrame):
	var titlebar = frame.get_titlebar_hbox()
	titlebar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.double_click:
			var label: Label = null
			for child in titlebar.get_children():
				if child is Label:
					label = child
					break
			if not label:
				return
			label.visible = false
			var edit = _inline_edit_scene.instantiate()
			edit.text = frame.title
			titlebar.add_child(edit)
			edit.grab_focus()
			edit.select_all()
			var _commit = func():
				frame.title = edit.text
				label.visible = true
				edit.queue_free()
			edit.text_submitted.connect(func(_t): _commit.call())
			edit.focus_exited.connect(_commit))
