extends VBoxContainer

signal toggled(plugin_id: String, enabled: bool)

@export var enabled_check: CheckBox
@export var display_name_label: Label
@export var author_label: Label
@export var file_version_label: Label

var plugin_id: String = ""


func setup(data: Dictionary, enabled: bool = true):
	plugin_id = data.get("id", "")
	var display_name = data.get("name", data.get("id", "Unknown"))
	var author = data.get("author", "")
	var version = data.get("version", "")
	var file_name = data.get("filename", "")
	var is_core = data.get("core", false)

	enabled_check.button_pressed = enabled
	if is_core:
		enabled_check.disabled = true
		enabled_check.tooltip_text = "Core plugin (always enabled)"
	else:
		enabled_check.toggled.connect(_on_toggled)
	display_name_label.text = display_name

	if author != "":
		author_label.text = "by: " + author
	else:
		author_label.text = ""

	var bottom_text = file_name
	if version != "":
		bottom_text += "  •  v" + version
	file_version_label.text = bottom_text


func _on_toggled(pressed: bool):
	toggled.emit(plugin_id, pressed)
