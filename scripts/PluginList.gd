extends Control

signal back_pressed
signal plugins_changed

@export var plugin_list: VBoxContainer
@export var back_button: Button

var PluginEntryScene = preload("res://scenes/PluginEntry.tscn")
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
	for data in plugins:
		_add_plugin_entry(data)


func _add_plugin_entry(data: Dictionary):
	var entry = PluginEntryScene.instantiate()
	plugin_list.add_child(entry)
	var plugin_id = data.get("id", "")
	entry.setup(data, config.is_enabled(plugin_id))
	entry.toggled.connect(_on_plugin_toggled)


func _on_plugin_toggled(plugin_id: String, enabled: bool):
	config.set_enabled(plugin_id, enabled)
	plugins_changed.emit()
