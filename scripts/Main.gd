extends Control

@export var main_menu: Control
@export var game_view: Control
@export var node_editor: Control
@export var module_select: Control
@export var plugin_list: Control

var module
var api = ModAPI.new()
var plugin_config := PluginConfig.new()
var context = {}
var current_node_id
var current_module_path: String = ""


func _ready():
	# Ensure user directories exist
	DirAccess.make_dir_recursive_absolute(SystemUtils.SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(SystemUtils.MODULES_DIR)
	DirAccess.make_dir_recursive_absolute(SystemUtils.PLUGINS_DIR)

	# Load only enabled plugins
	_reload_plugins()

	# Pass plugin hints to the editor and game view
	node_editor.set_api(api)
	game_view.set_api(api)

	# Connect UI
	main_menu.new_game_pressed.connect(_show_module_select)
	main_menu.continue_pressed.connect(_continue_game)
	main_menu.load_game_pressed.connect(_load_game)
	main_menu.node_editor_pressed.connect(_show_node_editor)
	main_menu.plugins_pressed.connect(_show_plugin_list)
	main_menu.exit_pressed.connect(func(): get_tree().quit())

	node_editor.close_pressed.connect(_show_menu)

	module_select.module_selected.connect(_start_game)
	module_select.back_pressed.connect(_show_menu)

	plugin_list.back_pressed.connect(_show_menu)
	plugin_list.plugins_changed.connect(_reload_plugins)

	game_view.choice_selected.connect(_on_choice_selected)
	game_view.save_requested.connect(_save_game)
	game_view.quicksave_requested.connect(_quicksave_game)
	game_view.quickload_requested.connect(_quickload_game)
	game_view.load_requested.connect(_load_game)
	game_view.exit_requested.connect(_show_menu)

	_show_menu()


# -------------------------
# PLUGINS
# -------------------------

func _reload_plugins():
	plugin_config = PluginConfig.new()
	api.plugins.clear()
	api.plugin_metadata.clear()
	var loader = PluginLoader.new()
	var plugins = loader.load_all()
	for entry in plugins:
		var meta = entry.get("metadata", {})
		var is_core = meta.get("core", false)
		if is_core or plugin_config.is_enabled(entry["id"]):
			api.register_plugin(entry["id"], entry["plugin"], meta)
	node_editor.set_api(api)
	game_view.set_api(api)
	module_select.api = api


# -------------------------
# STATES
# -------------------------

func _show_menu():
	main_menu.visible = true
	game_view.visible = false
	node_editor.visible = false
	module_select.visible = false
	plugin_list.visible = false


func _show_node_editor():
	main_menu.visible = false
	game_view.visible = false
	node_editor.visible = true
	module_select.visible = false
	plugin_list.visible = false


func _show_module_select():
	main_menu.visible = false
	game_view.visible = false
	node_editor.visible = false
	module_select.visible = true
	plugin_list.visible = false


func _show_plugin_list():
	main_menu.visible = false
	game_view.visible = false
	node_editor.visible = false
	module_select.visible = false
	plugin_list.visible = true


func _continue_game():
	var last_save = main_menu._find_last_save()
	if last_save != "":
		_load_save_file(last_save)


func _start_game(path: String):
	main_menu.visible = false
	game_view.visible = true
	node_editor.visible = false
	module_select.visible = false
	plugin_list.visible = false

	current_module_path = path
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))

	module = Module.new()
	module.init(data, api)

	context = {}
	api.notify_game_started(context)
	current_node_id = module.start_node

	_enter_node()


func _enter_node():
	module.enter_node(current_node_id, context)
	api.notify_context_changed(context)

	var node = module.get_node(current_node_id)
	game_view.display_node(node, module, context)


func _on_choice_selected(choice):
	if choice.get("_end_game", false):
		_show_menu()
		return
	for action in choice.get("actions", []):
		module._execute_action(action, context)
	api.notify_context_changed(context)
	var next = choice.get("next", "")
	if next != "":
		current_node_id = next
	_enter_node()


# -------------------------
# SAVE / LOAD
# -------------------------

func _get_save_data() -> Dictionary:
	return {
		"module_path": current_module_path,
		"module_version": module.version if module else "",
		"node_id": current_node_id,
		"context": context,
	}


func _write_save(path: String):
	var json = JSON.stringify(_get_save_data(), "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json)
	file.close()


func _quicksave_game():
	_write_save(SystemUtils.QUICKSAVE_PATH)


func _quickload_game():
	_load_save_file(SystemUtils.QUICKSAVE_PATH)


func _save_game():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.current_dir = SystemUtils.SAVE_DIR
	dialog.filters = PackedStringArray(["*.sav ; Save Files"])
	dialog.file_selected.connect(func(path):
		_write_save(path)
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _load_game():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.current_dir = SystemUtils.SAVE_DIR
	dialog.filters = PackedStringArray(["*.sav ; Save Files"])
	dialog.file_selected.connect(func(path):
		dialog.queue_free()
		_load_save_file(path))
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _load_save_file(save_path: String):
	if not FileAccess.file_exists(save_path):
		return
	var json = FileAccess.get_file_as_string(save_path)
	var save_data = JSON.parse_string(json)
	if save_data == null:
		return

	var path = save_data.get("module_path", "")
	if path == "":
		return

	if not FileAccess.file_exists(path):
		_show_load_error("Module not found:\n" + path)
		return

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved_version = save_data.get("module_version", "")
	var current_version = data.get("version", "")

	if saved_version != "" and current_version != saved_version:
		_show_version_warning(saved_version, current_version, func():
			_apply_load(path, data, save_data))
		return

	_apply_load(path, data, save_data)


func _apply_load(path: String, data: Dictionary, save_data: Dictionary):
	current_module_path = path
	module = Module.new()
	module.init(data, api)

	context = save_data.get("context", {})
	current_node_id = save_data.get("node_id", module.start_node)

	main_menu.visible = false
	game_view.visible = true
	node_editor.visible = false
	module_select.visible = false
	plugin_list.visible = false

	api.notify_context_changed(context)
	var node = module.get_node(current_node_id)
	game_view.display_node(node, module, context)


func _show_load_error(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Load Error"
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _show_version_warning(saved_ver: String, current_ver: String, on_continue: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.title = "Version Mismatch"
	dialog.dialog_text = "Save was made with module version %s,\nbut the current version is %s.\n\nContinue loading?" % [saved_ver, current_ver]
	dialog.confirmed.connect(func():
		dialog.queue_free()
		on_continue.call())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
