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

var _api: ModAPI = null
var _hud_nodes: Array[Node] = []
var _overlay_nodes: Dictionary = {}  # id → PluginOverlay instance
var _sidebar_nodes: Array[Node] = []
var _last_context: Dictionary = {}


func set_api(api: ModAPI):
	_api = api
	api.context_changed_callback = _on_context_changed
	api.show_overlay_callback = show_overlay
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
		if instance.has_method("set_api"):
			instance.set_api(_api)
		_sidebar_nodes.append(instance)

	# System buttons
	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func(): save_requested.emit())
	sidebar_container.add_child(save_btn)
	_sidebar_nodes.append(save_btn)

	var quicksave_btn = Button.new()
	quicksave_btn.text = "Quick Save"
	quicksave_btn.pressed.connect(func(): quicksave_requested.emit())
	sidebar_container.add_child(quicksave_btn)
	_sidebar_nodes.append(quicksave_btn)

	var quickload_btn = Button.new()
	quickload_btn.text = "Quick Load"
	quickload_btn.disabled = not FileAccess.file_exists(SystemUtils.QUICKSAVE_PATH)
	quickload_btn.pressed.connect(func(): quickload_requested.emit())
	sidebar_container.add_child(quickload_btn)
	_sidebar_nodes.append(quickload_btn)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(func(): load_requested.emit())
	sidebar_container.add_child(load_btn)
	_sidebar_nodes.append(load_btn)

	var exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	sidebar_container.add_child(exit_btn)
	_sidebar_nodes.append(exit_btn)


func show_overlay(overlay_id: String, params: Dictionary = {}):
	if not _overlay_nodes.has(overlay_id):
		push_warning("[GameView] Overlay not found: ", overlay_id)
		return
	var overlay = _overlay_nodes[overlay_id]
	if overlay is PluginOverlay:
		overlay.update_context(_last_context)
		overlay.open(params)


func _on_context_changed(context: Dictionary):
	_last_context = context
	for node in _hud_nodes:
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
	var path = node.get("image", "")
	if path != "":
		image.texture = load(path)
		image.visible = true
	else:
		image.visible = false

	# Notify HUD
	_on_context_changed(context)

	# CHOICES
	_build_choices(node, module, context)


func _build_choices(node, module, context):
	for c in choices_container.get_children():
		c.queue_free()

	var choices = node.get("choices", [])

	if choices.is_empty():
		var btn = Button.new()
		btn.text = "Back to Main Menu"
		btn.pressed.connect(func():
			choice_selected.emit({"_end_game": true})
		)
		choices_container.add_child(btn)
		return

	for choice in choices:
		var btn = Button.new()
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
