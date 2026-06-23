extends Control

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
var node_map = {}
var id_map = {}
var frames = []
var selected_node: StoryNode = null

var _api: ModAPI = null
var _last_export_path: String = ""
var _module_entries: Dictionary = {}
var _module_active: bool = false
var _dep_dialog: Control = null
var _pending_save_path: String = ""
var _context_menu: PopupMenu = null
var _context_menu_position: Vector2 = Vector2.ZERO

var _frame_manager: GraphFrameManager
var _node_factory: GraphNodeFactory
var _serializer: ModuleSerializer


func set_api(api: ModAPI):
	_api = api
	node_inspector.available_actions = api.get_all_actions()
	node_inspector.available_conditions = api.get_all_conditions()
	node_inspector.api = api
	_serializer.set_api(api)


func get_module_entries() -> Dictionary:
	return _module_entries


func get_module_id() -> String:
	if module_id_edit.text != "":
		return module_id_edit.text
	return "editor_module"


func is_module_loaded() -> bool:
	return _module_active


func _ready() -> void:
	_frame_manager = GraphFrameManager.new()
	_frame_manager.setup(graph, nodes, frames)

	_node_factory = GraphNodeFactory.new()
	_node_factory.setup(graph, nodes, node_map, id_map, _frame_manager)
	_node_factory.node_selected.connect(_on_node_selected)

	_serializer = ModuleSerializer.new()
	_serializer.setup(graph, nodes, frames, _frame_manager)

	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.delete_nodes_request.connect(_on_delete_nodes_request)
	graph.gui_input.connect(_on_graph_gui_input)
	node_inspector.visible = false


func reset():
	_clear_editor()
	module_id_edit.text = ""
	module_name_edit.text = ""
	module_version_edit.text = ""
	module_author_edit.text = ""
	_last_export_path = ""
	_module_entries = {}
	_module_active = false
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


# --- Input & Context Menu ---

func _on_graph_gui_input(event):
	if graph.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.ctrl_pressed:
			_frame_manager.detach_selected_elements()
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_frame_manager.clear_drag_detach()


func _show_context_menu():
	_context_menu_position = (graph.get_local_mouse_position() + graph.scroll_offset) / graph.zoom
	if _context_menu:
		_context_menu.queue_free()
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Create Node", 0)
	_context_menu.add_item("Create Group", 1)
	_context_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(_context_menu)
	var mouse_screen = get_viewport().get_mouse_position()
	_context_menu.position = Vector2i(mouse_screen)
	_context_menu.popup()


func _on_context_menu_selected(id: int):
	match id:
		0: _node_factory.create_node_at(_context_menu_position)
		1: _frame_manager.create_frame_at(_context_menu_position)


# --- Node Selection ---

func _on_node_selected(node: StoryNode):
	selected_node = node
	node_inspector.load_node(node)


# --- Connections ---

func _on_connection_request(from, from_port, to, to_port):
	_node_factory.handle_connection(from, from_port, to, to_port)
	node_inspector.rebuild_choices_list()


func _on_disconnection_request(from, from_port, to, to_port):
	_node_factory.handle_disconnection(from, from_port, to, to_port)
	node_inspector.rebuild_choices_list()


# --- Delete ---

func _on_delete_nodes_request(node_names: Array[StringName]):
	for node_name in node_names:
		if str(node_name) == "__start__":
			continue
		var node = graph.get_node(NodePath(str(node_name)))
		if node is GraphFrame:
			_frame_manager.delete_frame(node)
		elif node is StoryNode:
			_node_factory.delete_node(node)


# --- Save / Load ---

func _on_save_pressed():
	if _last_export_path != "":
		_validate_then_save(_last_export_path)
	else:
		_validate_then_pick_file()


func _on_save_as_pressed():
	_validate_then_pick_file()


func _on_file_selected(path: String):
	_last_export_path = path
	_do_export(path)


func _validate_then_save(path: String):
	_pending_save_path = path
	if _check_dependencies():
		_do_export(path)


func _validate_then_pick_file():
	_pending_save_path = ""
	if _check_dependencies():
		save_file_dialog.popup_centered()


func _do_export(path: String):
	var metadata = {
		"id": module_id_edit.text if module_id_edit.text != "" else "editor_module",
		"name": module_name_edit.text,
		"version": module_version_edit.text,
		"author": module_author_edit.text,
	}
	_serializer.export_module(path, metadata, _node_factory.start_node_gn, _module_entries)


func _check_dependencies() -> bool:
	if _api == null:
		return true

	var module_nodes := []
	for n in nodes:
		module_nodes.append(n.data)

	if _dep_dialog:
		_dep_dialog.queue_free()

	var dialog = load("res://ui/editor/DependencyCheckDialog.tscn").instantiate()
	add_child(dialog)
	_dep_dialog = dialog

	var has_issues = dialog.check_and_show(module_nodes, _api, module_id_edit.text, _module_entries)
	if not has_issues:
		_dep_dialog.queue_free()
		_dep_dialog = null
		return true
	else:
		dialog.confirmed_save.connect(_on_dep_confirmed)
		dialog.cancelled_save.connect(_on_dep_cancelled)
		return false


func _on_dep_confirmed():
	if _dep_dialog:
		_dep_dialog.queue_free()
		_dep_dialog = null
	if _pending_save_path != "":
		_do_export(_pending_save_path)
	else:
		save_file_dialog.popup_centered()


func _on_dep_cancelled():
	if _dep_dialog:
		_dep_dialog.queue_free()
		_dep_dialog = null


# --- New / Open ---

func _on_new_pressed():
	_clear_editor()
	module_id_edit.text = ""
	module_name_edit.text = ""
	module_version_edit.text = ""
	module_author_edit.text = ""
	_last_export_path = ""
	_module_entries = {}
	_module_active = true
	_set_module_controls_enabled(true)
	_node_factory.create_start_node()


func _on_open_pressed():
	open_file_dialog.popup_centered()


func _on_open_file_selected(path: String):
	load_module(path)


func load_module(path: String):
	var data = _serializer.load_module(path)
	if data.is_empty():
		return

	_clear_editor()
	_module_active = true
	_set_module_controls_enabled(true)

	module_id_edit.text = data.get("id", "")
	module_name_edit.text = data.get("name", "")
	module_version_edit.text = data.get("version", "")
	module_author_edit.text = data.get("author", "")
	_last_export_path = path
	_module_entries = data.get("entries", {})

	# Create nodes from data
	var node_data_map = data.get("nodes", {})
	for node_id in node_data_map:
		_node_factory.create_node_from_data(node_id, node_data_map[node_id])

	_node_factory.restore_connections()

	# Select start node
	var start_id = data.get("start_node", "")
	if id_map.has(start_id):
		selected_node = id_map[start_id]
		node_inspector.load_node(selected_node)

	_node_factory.create_start_node()
	_node_factory.connect_start_to(start_id)

	# Restore frames
	_frame_manager.restore_frames(data.get("frames", []), id_map)


func _clear_editor():
	_node_factory.clear_all()
	_frame_manager.clear_all()
	selected_node = null
	node_inspector.clear()
