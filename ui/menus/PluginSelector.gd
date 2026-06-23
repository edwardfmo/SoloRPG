## Popup dialog for selecting optional plugins before starting a game.
## Reuses PluginEntry scene for each plugin row.
extends Control

signal confirmed_selection(enabled_ids: Array)
signal canceled

var PluginEntryScene = preload("res://ui/menus/PluginEntry.tscn")
var _section_label_scene = preload("res://ui/shared/SectionLabel.tscn")
@export var _plugin_list: VBoxContainer
@export var _title_label: Label
var _selections := {}  # plugin_id → bool


func _ready():
	_refresh_list()


func _refresh_list():
	for child in _plugin_list.get_children():
		child.queue_free()
	_selections.clear()

	var config = PluginConfig.new()
	var loader = PluginLoader.new()
	var plugins = loader.scan_metadata()

	var has_optional = false
	for data in plugins:
		var ptype = SystemUtils.get_plugin_type(data)
		if ptype == "optional":
			has_optional = true
			var plugin_id = data.get("id", "")
			var enabled = config.is_enabled(plugin_id)
			_selections[plugin_id] = enabled
			var entry = PluginEntryScene.instantiate()
			_plugin_list.add_child(entry)
			entry.setup(data, enabled, true)
			entry.toggled.connect(_on_plugin_toggled)

	if not has_optional:
		var label = _section_label_scene.instantiate()
		label.text = "No optional plugins installed"
		label.modulate = Color(0.5, 0.5, 0.5)
		_plugin_list.add_child(label)


func _on_plugin_toggled(plugin_id: String, enabled: bool):
	_selections[plugin_id] = enabled


func _on_confirmed():
	var enabled_ids: Array[String] = []
	for id in _selections:
		if _selections[id]:
			enabled_ids.append(id)
	confirmed_selection.emit(enabled_ids)
	queue_free()


func _on_cancel():
	canceled.emit()
	queue_free()
