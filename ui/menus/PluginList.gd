extends Control

signal back_pressed
signal plugins_changed

@export var plugin_list: VBoxContainer
@export var back_button: Button

var PluginEntryScene = preload("res://ui/menus/PluginEntry.tscn")
var config := PluginConfig.new()


func _ready():
	back_button.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	if visible:
		_refresh_list()


func _refresh_list():
	for child in plugin_list.get_children():
		child.queue_free()

	var loader = PluginLoader.new()
	var plugins = loader.scan_metadata()

	var optional_plugins := []
	var module_required_plugins := []
	var core_plugins := []

	for data in plugins:
		var ptype = _get_plugin_type(data)
		if ptype == "optional":
			optional_plugins.append(data)
		elif ptype == "module_required":
			module_required_plugins.append(data)
		else:
			core_plugins.append(data)

	_add_section_label("Optional")
	if optional_plugins.is_empty():
		_add_empty_label()
	else:
		for data in optional_plugins:
			_add_plugin_entry(data, true)

	_add_section_label("Module Required")
	if module_required_plugins.is_empty():
		_add_empty_label()
	else:
		for data in module_required_plugins:
			_add_plugin_entry(data, false)

	_add_section_label("Core")
	if core_plugins.is_empty():
		_add_empty_label()
	else:
		for data in core_plugins:
			_add_plugin_entry(data, false)


func _add_section_label(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.7, 0.7, 0.7)
	plugin_list.add_child(label)


func _add_empty_label():
	var label = Label.new()
	label.text = "None installed"
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.5, 0.5, 0.5)
	plugin_list.add_child(label)


func _add_plugin_entry(data: Dictionary, show_toggle: bool):
	var entry = PluginEntryScene.instantiate()
	plugin_list.add_child(entry)
	var plugin_id = data.get("id", "")
	entry.setup(data, config.is_enabled(plugin_id), show_toggle)
	if show_toggle:
		entry.toggled.connect(_on_plugin_toggled)


func _get_plugin_type(data: Dictionary) -> String:
	if data.has("type"):
		return data["type"]
	if data.get("core", false):
		return "core"
	return "optional"


func _on_plugin_toggled(plugin_id: String, enabled: bool):
	config.set_enabled(plugin_id, enabled)
	plugins_changed.emit()
