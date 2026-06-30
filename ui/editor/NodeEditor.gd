extends Control

@export var graph: GraphEdit
@export var module_id_edit: LineEdit
@export var module_name_edit: LineEdit
@export var module_version_edit: LineEdit
@export var module_author_edit: LineEdit

@export var node_inspector: ScrollContainer

@export var save_button: Button
@export var save_as_button: Button
@export var settings_button: Button
@export var module_settings_panel: Control

@export var save_file_dialog: FileDialog
@export var open_file_dialog: FileDialog
@export var context_menu: PopupMenu

var nodes = []
var node_map = {}
var id_map = {}
var frames = []
var selected_node: StoryNode = null

var _api: ModAPI = null
var _module_dir_path: String = ""
var _module_entries: Dictionary = {}
var _module_settings: Dictionary = {}
var _module_active: bool = false
var _pending_save_path: String = ""
var _context_menu_position: Vector2 = Vector2.ZERO

var _frame_manager: GraphFrameManager
var _node_factory: GraphNodeFactory
var _serializer: ModuleSerializer
var _image_file_dialog: FileDialog
var _export_images_dialog: ConfirmationDialog


func set_api(api: ModAPI):
	_api = api
	node_inspector.available_actions = api.get_all_actions()
	node_inspector.available_conditions = api.get_all_conditions()
	node_inspector.api = api
	_serializer.set_api(api)
	module_settings_panel.set_api(api)


func get_module_entries() -> Dictionary:
	return _module_entries


func get_module_id() -> String:
	if module_id_edit.text != "":
		return module_id_edit.text
	return "editor_module"


func get_module_dir_path() -> String:
	return _module_dir_path


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
	node_inspector.image_browse_requested.connect(_on_image_browse_requested)
	node_inspector.image_path_set.connect(_on_image_path_set)

	# Image file dialog (created in code to avoid .tscn bloat)
	_image_file_dialog = FileDialog.new()
	_image_file_dialog.title = "Select Image"
	_image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_image_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	_image_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_image_file_dialog.size = Vector2i(600, 400)
	_image_file_dialog.file_selected.connect(_on_image_file_selected)
	add_child(_image_file_dialog)

	# Export images confirmation dialog
	_export_images_dialog = ConfirmationDialog.new()
	_export_images_dialog.title = "Export Images"
	_export_images_dialog.dialog_text = "The module contains images that are not referenced by any node.\n\nExport only referenced images?"
	_export_images_dialog.get_ok_button().text = "Referenced Only"
	_export_images_dialog.add_button("All Images", true, "all_images")
	add_child(_export_images_dialog)


func reset():
	_clear_editor()
	module_id_edit.text = ""
	module_name_edit.text = ""
	module_version_edit.text = ""
	module_author_edit.text = ""
	_module_dir_path = ""
	_module_entries = {}
	_module_settings = {}
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
	settings_button.disabled = not enabled


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
	context_menu.clear()
	context_menu.add_item("Create Node", 0)
	context_menu.add_item("Create Group", 1)
	if not context_menu.id_pressed.is_connected(_on_context_menu_selected):
		context_menu.id_pressed.connect(_on_context_menu_selected)
	var mouse_screen = get_viewport().get_mouse_position()
	context_menu.position = Vector2i(mouse_screen)
	context_menu.popup()


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
	_validate_then_save("")


func _on_save_as_pressed():
	_validate_then_pick_file()


func _on_settings_pressed():
	if not _module_active or _api == null:
		return
	var module_nodes := []
	for n in nodes:
		module_nodes.append(n.data)
	var mid = module_id_edit.text if module_id_edit.text != "" else "editor_module"
	module_settings_panel.open(module_nodes, _module_settings, mid, _module_entries)
	if not module_settings_panel.closed.is_connected(_on_settings_closed):
		module_settings_panel.closed.connect(_on_settings_closed, CONNECT_ONE_SHOT)


func _on_settings_closed():
	_module_settings = module_settings_panel.get_module_settings()


func _on_file_selected(path: String):
	# path is the .rpgmod export target
	_do_export_zip(path)


func _validate_then_save(_path: String):
	_pending_save_path = "save"
	_show_save_confirm()


func _validate_then_pick_file():
	_pending_save_path = "export"
	_show_save_confirm()


func _show_save_confirm():
	var module_nodes := []
	for n in nodes:
		module_nodes.append(n.data)
	var mid = module_id_edit.text if module_id_edit.text != "" else "editor_module"
	module_settings_panel.open_confirm(module_nodes, _module_settings, mid, _module_entries)
	if not module_settings_panel.confirmed_save.is_connected(_on_save_confirmed):
		module_settings_panel.confirmed_save.connect(_on_save_confirmed, CONNECT_ONE_SHOT)
	if not module_settings_panel.cancelled_save.is_connected(_on_save_cancelled):
		module_settings_panel.cancelled_save.connect(_on_save_cancelled, CONNECT_ONE_SHOT)


func _on_save_confirmed():
	_module_settings = module_settings_panel.get_module_settings()
	if module_settings_panel.cancelled_save.is_connected(_on_save_cancelled):
		module_settings_panel.cancelled_save.disconnect(_on_save_cancelled)
	if _pending_save_path == "save":
		_do_save()
	else:
		# Export to .rpgmod — show file picker
		save_file_dialog.popup_centered()


func _on_save_cancelled():
	if module_settings_panel.confirmed_save.is_connected(_on_save_confirmed):
		module_settings_panel.confirmed_save.disconnect(_on_save_confirmed)


## Save to the module directory (always saves; creates dir if needed).
func _do_save():
	_ensure_module_dir()
	var metadata = _get_metadata()
	_serializer.save_to_directory(_module_dir_path, metadata, _node_factory.start_node_gn, _module_entries, _module_settings)


## Export to .rpgmod ZIP, optionally asking about unreferenced images.
func _do_export_zip(zip_path: String):
	_ensure_module_dir()
	var metadata = _get_metadata()
	# Save to directory first
	_serializer.save_to_directory(_module_dir_path, metadata, _node_factory.start_node_gn, _module_entries, _module_settings)

	# Check for unreferenced images
	if _serializer.has_unreferenced_images(_module_dir_path):
		_pending_save_path = zip_path
		_show_export_images_dialog(zip_path)
	else:
		_serializer.export_to_zip(zip_path, _module_dir_path, metadata, _node_factory.start_node_gn, _module_entries, _module_settings, false)


func _show_export_images_dialog(zip_path: String):
	# Use lambdas with one-shot connections
	var on_ok := func():
		var m = _get_metadata()
		_serializer.export_to_zip(zip_path, _module_dir_path, m, _node_factory.start_node_gn, _module_entries, _module_settings, true)
	var on_all := func(action: String):
		if action == "all_images":
			var m = _get_metadata()
			_serializer.export_to_zip(zip_path, _module_dir_path, m, _node_factory.start_node_gn, _module_entries, _module_settings, false)
			_export_images_dialog.hide()

	_export_images_dialog.confirmed.connect(on_ok, CONNECT_ONE_SHOT)
	_export_images_dialog.custom_action.connect(on_all, CONNECT_ONE_SHOT)
	_export_images_dialog.canceled.connect(func():
		# Clean up other one-shot connections on cancel
		if _export_images_dialog.confirmed.is_connected(on_ok):
			_export_images_dialog.confirmed.disconnect(on_ok)
		if _export_images_dialog.custom_action.is_connected(on_all):
			_export_images_dialog.custom_action.disconnect(on_all)
	, CONNECT_ONE_SHOT)
	_export_images_dialog.popup_centered()


func _get_metadata() -> Dictionary:
	return {
		"id": module_id_edit.text if module_id_edit.text != "" else "editor_module",
		"name": module_name_edit.text,
		"version": module_version_edit.text,
		"author": module_author_edit.text,
	}


func _ensure_module_dir():
	if _module_dir_path == "":
		var mid = module_id_edit.text if module_id_edit.text != "" else "editor_module"
		_module_dir_path = SystemUtils.MODULES_DIR + mid
	# Globalize res:// paths for filesystem operations
	if _module_dir_path.begins_with("res://"):
		_module_dir_path = ProjectSettings.globalize_path(_module_dir_path)
	DirAccess.make_dir_recursive_absolute(_module_dir_path)
	DirAccess.make_dir_recursive_absolute(_module_dir_path + "/images")


# --- New / Open ---

func _on_new_pressed():
	_clear_editor()
	module_id_edit.text = ""
	module_name_edit.text = ""
	module_version_edit.text = ""
	module_author_edit.text = ""
	_module_dir_path = ""
	_module_entries = {}
	_module_settings = {}
	_module_active = true
	_set_module_controls_enabled(true)
	_node_factory.create_start_node()


func _on_open_pressed():
	open_file_dialog.popup_centered()


func _on_open_file_selected(path: String):
	if path.ends_with(".rpgmod"):
		_open_rpgmod(path)
	else:
		load_module(path)


func _open_rpgmod(rpgmod_path: String):
	# Check if a directory already exists for this archive
	var zip = ZIPReader.new()
	if zip.open(rpgmod_path) != OK:
		return
	var json_data = zip.read_file("module.json")
	zip.close()
	if json_data.is_empty():
		return
	var data = JSON.parse_string(json_data.get_string_from_utf8())
	if data == null:
		return
	var module_id = data.get("id", "imported_module")

	# Check both user and bundled module directories
	var existing_dir := ""
	for search_dir in [SystemUtils.MODULES_DIR, SystemUtils.BUNDLED_MODULES_DIR + "/"]:
		var candidate = search_dir + module_id
		if DirAccess.dir_exists_absolute(candidate):
			existing_dir = candidate
			break

	if existing_dir != "":
		# Prompt user
		var dest_dir = SystemUtils.MODULES_DIR + module_id
		var dialog = ConfirmationDialog.new()
		dialog.title = "Module Already Exists"
		dialog.dialog_text = "A folder for '%s' already exists.\n\nExtract and overwrite existing content?" % module_id
		dialog.get_ok_button().text = "Overwrite"
		dialog.add_button("Open Existing", true, "open_existing")
		add_child(dialog)
		dialog.confirmed.connect(func():
			dialog.queue_free()
			_serializer.import_from_zip(rpgmod_path, true)
			load_module(dest_dir))
		dialog.custom_action.connect(func(action):
			if action == "open_existing":
				dialog.queue_free()
				load_module(existing_dir))
		dialog.canceled.connect(func():
			dialog.queue_free())
		dialog.popup_centered()
	else:
		# No existing directory — extract and open
		load_module(rpgmod_path)


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
	_module_dir_path = data.get("_dir_path", "")
	_module_entries = data.get("entries", {})
	_module_settings = data.get("settings", {})

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


# --- Image Browsing ---

func _on_image_browse_requested():
	if not _module_active:
		return
	_image_file_dialog.popup_centered()


func _on_image_file_selected(source_path: String):
	_ensure_module_dir()
	var rel_path = _serializer.copy_image_to_module(source_path, _module_dir_path)
	if selected_node:
		selected_node.data["image"] = rel_path
		node_inspector.set_image_path(rel_path)


func _on_image_path_set(path: String):
	if not _module_active or path == "":
		return
	# If it's already a relative path (images/...) or empty, nothing to do
	if path.begins_with("images/"):
		return
	# If it's an absolute filesystem path, copy it into the module
	if path.begins_with("/") or (path.length() > 2 and path[1] == ":"):
		if FileAccess.file_exists(path):
			_ensure_module_dir()
			var rel_path = _serializer.copy_image_to_module(path, _module_dir_path)
			if selected_node:
				selected_node.data["image"] = rel_path
				node_inspector.set_image_path(rel_path)


func _clear_editor():
	_node_factory.clear_all()
	_frame_manager.clear_all()
	selected_node = null
	node_inspector.clear()
