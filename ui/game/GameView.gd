extends Control

signal choice_selected(choice_data)
signal save_requested
signal quicksave_requested
signal quickload_requested
signal load_requested
signal exit_requested

@export var image: TextureRect
@export var text: Label
@export var choices_container: VBoxContainer
@export var hud_container: VBoxContainer
@export var overlay_container: Control
@export var sidebar_container: VBoxContainer
@export var save_button: Button
@export var quicksave_button: Button
@export var quickload_button: Button
@export var load_button: Button
@export var exit_button: Button

var _choice_scene = preload("res://ui/game/ChoiceButton.tscn")
var _api: ModAPI = null
var _hud_nodes: Array[Node] = []
var _overlay_nodes: Dictionary = {}  # id → PluginOverlay instance
var _sidebar_nodes: Array[Node] = []
var _last_context: Dictionary = {}
var _module_dir_path: String = ""


func set_module_dir(dir_path: String):
	_module_dir_path = dir_path


func set_api(api: ModAPI):
	_api = api
	api.context_changed_callback = _on_context_changed
	api.show_overlay_callback = show_overlay
	api.get_overlay_node_callback = get_overlay_node
	_load_hud_panels()
	_load_overlay_panels()
	_load_sidebar_icons()


func _load_hud_panels():
	# Clear existing plugin HUD nodes
	for node in _hud_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_hud_nodes.clear()

	if _api == null:
		return

	var panels = _api.get_ui_panels_for_slot("game_hud")
	for panel_info in panels:
		var scene_path = panel_info.get("scene", "")
		if scene_path == "":
			continue
		var scene = load(scene_path)
		if scene == null:
			push_warning("[GameView] Failed to load HUD scene: ", scene_path)
			continue
		var instance = scene.instantiate()
		hud_container.add_child(instance)
		_hud_nodes.append(instance)


func _load_overlay_panels():
	# Clear existing overlays
	for id in _overlay_nodes:
		var node = _overlay_nodes[id]
		if is_instance_valid(node):
			node.queue_free()
	_overlay_nodes.clear()

	if _api == null:
		return

	var panels = _api.get_ui_panels_for_slot("game_overlay")
	for panel_info in panels:
		var scene_path = panel_info.get("scene", "")
		var overlay_id = panel_info.get("id", "")
		if scene_path == "" or overlay_id == "":
			continue
		var scene = load(scene_path)
		if scene == null:
			push_warning("[GameView] Failed to load overlay scene: ", scene_path)
			continue
		var instance = scene.instantiate()
		overlay_container.add_child(instance)
		instance.visible = false
		if "api" in instance:
			instance.api = _api
		_overlay_nodes[overlay_id] = instance


func _load_sidebar_icons():
	for node in _sidebar_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_sidebar_nodes.clear()

	if _api == null:
		return

	var panels = _api.get_ui_panels_for_slot("sidebar_icon")
	for panel_info in panels:
		var scene_path = panel_info.get("scene", "")
		if scene_path == "":
			continue
		var scene = load(scene_path)
		if scene == null:
			push_warning("[GameView] Failed to load sidebar icon: ", scene_path)
			continue
		var instance = scene.instantiate()
		sidebar_container.add_child(instance)
		sidebar_container.move_child(instance, sidebar_container.get_child_count() - 6)
		if instance.has_method("set_api"):
			instance.set_api(_api)
		_sidebar_nodes.append(instance)

	# Wire system buttons
	save_button.pressed.connect(func(): save_requested.emit())
	quicksave_button.pressed.connect(func(): quicksave_requested.emit())
	quickload_button.disabled = not FileAccess.file_exists(SystemUtils.QUICKSAVE_PATH)
	quickload_button.pressed.connect(func(): quickload_requested.emit())
	load_button.pressed.connect(func(): load_requested.emit())
	exit_button.pressed.connect(func(): exit_requested.emit())


func show_overlay(overlay_id: String, params: Dictionary = {}):
	if not _overlay_nodes.has(overlay_id):
		push_warning("[GameView] Overlay not found: ", overlay_id)
		return
	var overlay = _overlay_nodes[overlay_id]
	if overlay is PluginOverlay:
		overlay.update_context(_last_context)
		overlay.open(params)
		overlay_container.move_to_front()


func get_overlay_node(overlay_id: String) -> PluginOverlay:
	if not _overlay_nodes.has(overlay_id):
		return null
	var overlay = _overlay_nodes[overlay_id]
	if overlay is PluginOverlay:
		return overlay
	return null


func _on_context_changed(context: Dictionary):
	_last_context = context
	for node in _hud_nodes:
		if is_instance_valid(node) and node.has_method("update_context"):
			node.update_context(context)
	for node in _sidebar_nodes:
		if is_instance_valid(node) and node.has_method("update_context"):
			node.update_context(context)
	# Also update visible overlays
	for id in _overlay_nodes:
		var overlay = _overlay_nodes[id]
		if is_instance_valid(overlay) and overlay.visible and overlay.has_method("update_context"):
			overlay.update_context(context)


func display_node(node: Dictionary, module, context):
	# TEXT
	text.text = node.get("text", "")

	# IMAGE
	var img_path = node.get("image", "")
	if img_path != "":
		var tex = _load_module_image(img_path)
		if tex:
			image.texture = tex
			image.visible = true
		else:
			image.visible = false
	else:
		image.visible = false

	# Notify HUD
	_on_context_changed(context)

	# CHOICES
	_build_choices(node, module, context)


## Load an image from the module directory (relative path) or as a resource path.
func _load_module_image(img_path: String) -> Texture2D:
	# If it's already an absolute resource path, load directly
	if img_path.begins_with("res://") or img_path.begins_with("user://"):
		if ResourceLoader.exists(img_path):
			return load(img_path)
		return null

	# Relative path — resolve against module directory
	if _module_dir_path != "":
		var full_path = _module_dir_path + "/" + img_path
		if FileAccess.file_exists(full_path):
			var img = Image.load_from_file(full_path)
			if img:
				return ImageTexture.create_from_image(img)

	# Fallback: try loading as resource
	if ResourceLoader.exists(img_path):
		return load(img_path)
	return null


func _build_choices(node, module, context):
	for c in choices_container.get_children():
		c.queue_free()

	var choices = node.get("choices", [])

	if choices.is_empty():
		var btn = _choice_scene.instantiate()
		btn.text = "Back to Main Menu"
		btn.pressed.connect(func():
			choice_selected.emit({"_end_game": true})
		)
		choices_container.add_child(btn)
		return

	for choice in choices:
		var btn = _choice_scene.instantiate()
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
